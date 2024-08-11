import SwiftUI
import HotKey

@main
struct NotionBuddyApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject var sessionManager = SessionManager()

    init() {
        sessionManager.refreshAccounts()
        GlobalShortcutManager.shared.setupGlobalShortcut(sessionManager: sessionManager)
        StringArrayTransformer.register()
    }

    var body: some Scene {
        WindowGroup {
            if sessionManager.isAuthenticated {
                MainView(sessionManager: sessionManager)
                    .frame(width: 400, height: 640)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            } else {
                LoginView(sessionManager: sessionManager)
                    .frame(width: 400, height: 640)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 640)
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
