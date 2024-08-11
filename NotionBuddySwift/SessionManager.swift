import Foundation
import Combine
import AuthenticationServices
import SwiftUI

class SessionManager: ObservableObject {
    private var webAuthSession: ASWebAuthenticationSession?
    @Published var accounts: [NotionAccount] = []
    @Published var isAuthenticated: Bool = false
    @Published var _selectedAccountIndex: Int = -1
        
    var selectedAccountIndex: Int {
        get {
            return _selectedAccountIndex >= 0 && _selectedAccountIndex < accounts.count ? _selectedAccountIndex : -1
        }
        set {
            if newValue >= -1 && newValue < accounts.count {
                _selectedAccountIndex = newValue
            }
        }
    }
    
    var currentAccount: NotionAccount? {
        guard !accounts.isEmpty, selectedAccountIndex >= 0, selectedAccountIndex < accounts.count else {
            return nil
        }
        return accounts[selectedAccountIndex]
    }
    
    private let userDefaultsLogger = UserDefaultsLogger()
    var contextProvider = ContextProvider()
    private var cancellables = Set<AnyCancellable>()

    init() {
        logUserDefaults()
    }
    
    class ContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first!
        }
    }

    func logUserDefaults() {
        if let notionBuddyID = UserDefaults.standard.string(forKey: "notionBuddyID") {
            print("notionBuddyID: \(notionBuddyID)")
        } else {
            print("notionBuddyID not found in UserDefaults")
        }
    }

    func startWebAuthSession() {
        var urlString = "http://localhost:3000"
        if let notionBuddyID = UserDefaults.standard.string(forKey: "notionBuddyID") {
            urlString += "?notion_buddy_id=\(notionBuddyID)"
        }

        guard let url = URL(string: urlString) else { return }

        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "notionbuddy") { [weak self] callbackURL, error in
            guard let self = self, error == nil, let successURL = callbackURL else { return }

            guard let notionBuddyID = URLComponents(string: successURL.absoluteString)?.queryItems?.first(where: { $0.name == "notion_buddy_id" })?.value else { return }

            UserDefaults.standard.set(notionBuddyID, forKey: "notionBuddyID")

            DispatchQueue.main.async {
                self.fetchAccountData(notionBuddyID: notionBuddyID)
            }
        }

        session.presentationContextProvider = contextProvider
        session.start()
        
        self.webAuthSession = session
    }

    func fetchAccountData(notionBuddyID: String) {
        let urlString = "http://localhost:3000/get_accounts?notion_buddy_id=\(notionBuddyID)"

        guard let url = URL(string: urlString) else {
            print("Invalid URL for fetching account data.")
            return
        }

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: AccountsResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("Failed to fetch account data. Error: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] (response: AccountsResponse) in
                DispatchQueue.main.async {
                    self?.accounts = response.accounts
                    self?.selectedAccountIndex = self?.accounts.isEmpty == false ? 0 : -1
                    self?.isAuthenticated = !(self?.accounts.isEmpty ?? true)
                }
            })
            .store(in: &cancellables)
    }
    
    func refreshAccounts() {
        if let notionBuddyID = UserDefaults.standard.string(forKey: "notionBuddyID") {
            fetchAccountData(notionBuddyID: notionBuddyID)
        } else {
            self.accounts = []
            self.selectedAccountIndex = -1
            self.isAuthenticated = false
        }
    }
    
    func logoutAccount(_ account: NotionAccount) {
        guard let url = URL(string: "http://localhost:3000/logout") else {
            print("Invalid logout URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "notion_buddy_id": UserDefaults.standard.string(forKey: "notionBuddyID") ?? "",
            "account_id": account.id
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Failed to serialize logout request body: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Logout request failed: \(error)")
                    return
                }
                
                guard let self = self else { return }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if let index = self.accounts.firstIndex(where: { $0.id == account.id }) {
                        self.accounts.remove(at: index)
                        self.objectWillChange.send()
                        
                        if self.accounts.isEmpty {
                            self.selectedAccountIndex = -1
                            self.isAuthenticated = false
                            UserDefaults.standard.removeObject(forKey: "notionBuddyID")
                        } else if index <= self.selectedAccountIndex {
                            self.selectedAccountIndex = max(0, self.selectedAccountIndex - 1)
                        }
                    }
                    
                    // Remove account data from UserDefaults
                    UserDefaults.standard.removeObject(forKey: "account_\(account.id)")
                } else {
                    print("Logout failed with status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                }
            }
        }.resume()
    }
    
    struct AccountsResponse: Decodable {
        let accounts: [NotionAccount]
        let notionBuddyID: String
        
        enum CodingKeys: String, CodingKey {
            case accounts
            case notionBuddyID = "notion_buddy_id"
        }
    }
}
