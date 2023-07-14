import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @State private var webAuthSession: ASWebAuthenticationSession?
    @State private var accounts: [NotionAccount] = []
    @State private var selectedAccountIndex: Int = 0
    @State private var isAuthenticated: Bool = false

    var body: some View {
        if isAuthenticated {
            MainView(accessToken: self.accounts[selectedAccountIndex].accessToken)
        } else {
            VStack {
                Button(action: {
                    // Start the web authentication session
                    startWebAuthSession()
                }) {
                    Text("Authenticate with Notion")
                }

                if accounts.isEmpty {
                    ProgressView()
                } else {
                    Picker(selection: $selectedAccountIndex, label: Text("Select Account")) {
                        ForEach(accounts.indices, id: \.self) { index in
                            Text(self.accounts[index].name).tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 200)

                    displayAccountInfo(account: accounts[selectedAccountIndex])
                }
            }
            .frame(width: 552, height: 612)
            .onAppear {
                // Check if the user is returning from authentication
                if let notionBuddyID = UserDefaults.standard.string(forKey: "notionBuddyID") {
                    fetchAccountData(notionBuddyID: notionBuddyID)
                }
            }
        }
    }

    func startWebAuthSession() {
        var urlString = "http://localhost:3000"
        // Check if a notion_buddy_id is stored in the user defaults
        if let notionBuddyID = UserDefaults.standard.string(forKey: "notionBuddyID") {
            urlString += "?notion_buddy_id=\(notionBuddyID)"
        }

        guard let url = URL(string: urlString) else {
            return
        }

        webAuthSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "notionbuddy") { callbackURL, error in
            guard error == nil, let successURL = callbackURL else {
                return
            }

            guard let notionBuddyID = URLComponents(string: successURL.absoluteString)?.queryItems?.first(where: { $0.name == "notion_buddy_id" })?.value else {
                return
            }

            // Store the notionBuddyID in user defaults
            UserDefaults.standard.set(notionBuddyID, forKey: "notionBuddyID")

            // Use the notion_buddy_id to fetch the account data
            DispatchQueue.main.async {
                fetchAccountData(notionBuddyID: notionBuddyID)
            }
        }

        webAuthSession?.presentationContextProvider = contextProvider
        webAuthSession?.start()
    }


    func fetchAccountData(notionBuddyID: String) {
        let urlString = "http://localhost:3000/get_accounts?notion_buddy_id=\(notionBuddyID)"

        guard let url = URL(string: urlString) else {
            print("Invalid URL for fetching account data.")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Failed to fetch account data. Error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("Failed to retrieve account data.")
                return
            }
            
            do {
                let decodedData = try JSONDecoder().decode(AccountsResponse.self, from: data)
                DispatchQueue.main.async {
                    self.accounts = decodedData.accounts
                    self.selectedAccountIndex = self.accounts.indices.first ?? 0
                    self.isAuthenticated = true
                }
            } catch {
                print("Failed to decode account data. Error: \(error.localizedDescription)")
            }
        }.resume()
    }

    func displayAccountInfo(account: NotionAccount) -> some View {
        VStack {
            Text("Access Token: \(account.accessToken)")
            Text("Name: \(account.name)")
            
            if let urlString = account.avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .frame(width: 100, height: 100)
                } placeholder: {
                    ProgressView()
                }
            }
            
            Text("Workspace Name: \(account.workspaceName)")
            Text("Workspace Avatar: \(account.workspaceIcon ?? "")")
        }
    }
    
    var contextProvider = ContextProvider()
}

struct AccountsResponse: Decodable {
    let accounts: [NotionAccount]
    let notionBuddyID: String
    
    enum CodingKeys: String, CodingKey {
        case accounts
        case notionBuddyID = "notion_buddy_id"
    }
}

struct NotionAccount: Identifiable, Decodable, Hashable {
    let id: String
    let notionBuddyID: String
    let accessToken: String
    let name: String
    let email: String
    let avatarUrl: String?
    let workspaceName: String
    let workspaceIcon: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case notionBuddyID = "notion_buddy_id"
        case accessToken = "access_token"
        case name
        case email
        case avatarUrl = "avatar_url"
        case workspaceName = "workspace_name"
        case workspaceIcon = "workspace_icon"
    }
}

class ContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.keyWindow!
    }
}
