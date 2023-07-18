import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var sessionManager = SessionManager()

    var body: some View {
        VStack {
            Button(action: {
                // Start the web authentication session
                self.sessionManager.startWebAuthSession()
            }) {
                Text("Authenticate with Notion")
            }

            ProgressView()
                .hidden() // Hide the progress view since it's no longer needed
        }
        .onAppear {
            // Check if the user is returning from authentication
            if let notionBuddyID = UserDefaults.standard.string(forKey: "notionBuddyID") {
                sessionManager.fetchAccountData(notionBuddyID: notionBuddyID)
            }
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
