import SwiftUI

@main
struct NotionBuddyApp: App {
    let persistenceController = PersistenceController.shared
    @ObservedObject var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            if sessionManager.isAuthenticated {
                SidebarNavigationView(sessionManager: sessionManager)
                    .frame(minWidth: 560, idealWidth: 560, minHeight: 612, idealHeight: 612)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            } else {
                LoginView(sessionManager: sessionManager)
                    .frame(minWidth: 560, idealWidth: 560, minHeight: 612, idealHeight: 612)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}






class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "NotionBuddySwift")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
    }
}
