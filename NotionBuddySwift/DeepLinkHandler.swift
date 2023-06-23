import Combine
import Foundation

class DeepLinkHandler: ObservableObject {
    @Published var notionSecret: String = ""
    @Published var userName: String = ""
    @Published var avatar: Data? = nil
    @Published var workspaceName: String = ""

    func handleURL(_ url: URL) {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            // Parse the deep link URL and extract the data
            for item in queryItems {
                switch item.name {
                case "name":
                    userName = item.value ?? ""
                case "avatarUrl":
                    if let avatarUrlString = item.value, let avatarUrl = URL(string: avatarUrlString) {
                        downloadImage(from: avatarUrl)
                    }
                case "workspaceName":
                    workspaceName = item.value ?? ""
                case "notionApi":
                    if let value = item.value, let data = value.data(using: .utf8) {
                        let json = try? JSONSerialization.jsonObject(with: data, options: [])
                        if let dictionary = json as? [String: Any] {
                            notionSecret = dictionary["client_secret"] as? String ?? ""
                        }
                    }
                default:
                    break
                }
            }
        }
    }

    private func downloadImage(from url: URL) {
        URLSession.shared.dataTask(with:url) { data, response, error in
            if let data = data {
                DispatchQueue.main.async {
                    self.avatar = data
                }
            } else {
                print("Failed to download image:\(error?.localizedDescription ?? "Unknown error")")
            }
        }.resume()
    }
}
