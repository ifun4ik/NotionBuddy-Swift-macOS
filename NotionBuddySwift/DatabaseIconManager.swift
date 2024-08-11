import Foundation

class DatabaseIconManager {
    static let shared = DatabaseIconManager()
    
    private var icons: [String: DatabaseIcon] = [:]
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadIcons()
    }
    
    func setIcon(_ icon: DatabaseIcon?, for databaseId: String) {
        icons[databaseId] = icon
        saveIcons()
    }
    
    func getIcon(for databaseId: String) -> DatabaseIcon? {
        return icons[databaseId]
    }
    
    private func saveIcons() {
        let iconData = icons.mapValues { icon -> Data? in
            switch icon {
            case .emoji(let emoji):
                return try? JSONEncoder().encode(["type": "emoji", "value": emoji])
            case .url(let url):
                return try? JSONEncoder().encode(["type": "url", "value": url])
            case .custom(let data):
                return try? JSONEncoder().encode(["type": "custom", "value": data.base64EncodedString()])
            }
        }
        userDefaults.set(iconData, forKey: "databaseIcons")
    }
    
    private func loadIcons() {
        guard let iconData = userDefaults.dictionary(forKey: "databaseIcons") as? [String: Data] else { return }
        
        for (databaseId, data) in iconData {
            if let decodedData = try? JSONDecoder().decode([String: String].self, from: data) {
                switch decodedData["type"] {
                case "emoji":
                    icons[databaseId] = .emoji(decodedData["value"] ?? "")
                case "url":
                    icons[databaseId] = .url(decodedData["value"] ?? "")
                case "custom":
                    if let base64 = decodedData["value"], let imageData = Data(base64Encoded: base64) {
                        icons[databaseId] = .custom(imageData)
                    }
                default:
                    break
                }
            }
        }
    }
}
