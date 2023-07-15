import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var sessionManager = SessionManager()

    var body: some View {
        if sessionManager.isAuthenticated {
            MainView(sessionManager: self.sessionManager)
        } else {
            VStack {
                Button(action: {
                    // Start the web authentication session
                    self.sessionManager.startWebAuthSession()
                }) {
                    Text("Authenticate with Notion")
                }

                if sessionManager.accounts.isEmpty {
                    ProgressView()
                } else {
                    Picker(selection: $sessionManager.selectedAccountIndex, label: Text("Select Account")) {
                        ForEach(sessionManager.accounts.indices, id: \.self) { index in
                            Text(self.sessionManager.accounts[index].name).tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 200)

                    displayAccountInfo(account: sessionManager.accounts[sessionManager.selectedAccountIndex])
                }
            }
            .frame(width: 552, height: 612)
            .onAppear {
                // Check if the user is returning from authentication
                if let notionBuddyID = UserDefaults.standard.string(forKey: "notionBuddyID") {
                    sessionManager.fetchAccountData(notionBuddyID: notionBuddyID)
                }
            }
        }
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
