import Foundation

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
