import Foundation

class DatabaseIconManager {
    static let shared = DatabaseIconManager()
    
    private var icons: [String: DatabaseIcon] = [:]
    
    private init() {}
    
    func setIcon(_ icon: DatabaseIcon?, for databaseId: String) {
        icons[databaseId] = icon
    }
    
    func getIcon(for databaseId: String) -> DatabaseIcon? {
        return icons[databaseId]
    }
}
