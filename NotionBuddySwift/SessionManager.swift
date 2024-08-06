import Foundation
import Combine
import AuthenticationServices
import SwiftUI

class SessionManager: ObservableObject {
    private var webAuthSession: ASWebAuthenticationSession?
    @Published var accounts: [NotionAccount] = []
    @Published var selectedAccountIndex: Int = 0
    @Published var isAuthenticated: Bool = false
    
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
                    self?.selectedAccountIndex = self?.accounts.indices.first ?? 0
                    self?.isAuthenticated = true
                }
            })
            .store(in: &cancellables)
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
