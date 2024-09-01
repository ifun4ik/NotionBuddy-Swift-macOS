import SwiftUI
import HotKey
import CoreData

@main
struct NotionBuddyApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject var sessionManager = SessionManager()

    init() {
        sessionManager.refreshAccounts()
        GlobalShortcutManager.shared.setupGlobalShortcut(sessionManager: sessionManager)
        StringArrayTransformer.register()
//        PersistenceController.shared.resetDatabase()
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
        private let migrationManager = CustomMigrationManager()

        init(inMemory: Bool = false) {
            container = NSPersistentContainer(name: "NotionBuddySwift")
            if inMemory {
                container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
            }
            
            // Disable automatic migrations
            container.persistentStoreDescriptions.forEach { description in
                description.shouldMigrateStoreAutomatically = false
                description.shouldInferMappingModelAutomatically = false
            }
            
            container.loadPersistentStores { [weak self] (storeDescription, error) in
                if let error = error as NSError? {
                    // Handle migration error
                    if error.domain == NSCocoaErrorDomain && error.code == NSPersistentStoreIncompatibleVersionHashError {
                        print("Need to perform migration")
                        self?.performMigration(for: storeDescription)
                    } else {
                        fatalError("Unresolved error \(error), \(error.userInfo)")
                    }
                }
            }
        }
        
        private func performMigration(for storeDescription: NSPersistentStoreDescription) {
            guard let storeURL = storeDescription.url else {
                fatalError("Store URL is nil")
            }
            
            let destinationURL = storeURL.deletingLastPathComponent().appendingPathComponent("MigratedStore.sqlite")
            
            do {
                try migrationManager.migrateStore(at: storeURL, to: destinationURL, targetModel: container.managedObjectModel)
                
                // Replace the old store with the migrated store
                try container.persistentStoreCoordinator.replacePersistentStore(at: storeURL, destinationOptions: nil, withPersistentStoreFrom: destinationURL, sourceOptions: nil, ofType: NSSQLiteStoreType)
                
                // Remove the temporary migrated store
                try FileManager.default.removeItem(at: destinationURL)
                
                print("Migration completed successfully")
            } catch {
                fatalError("Migration failed: \(error)")
            }
        }

    func resetDatabase() {
        guard let url = container.persistentStoreDescriptions.first?.url else { return }

        let persistentStoreCoordinator = container.persistentStoreCoordinator

        do {
            try persistentStoreCoordinator.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
            try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        } catch {
            print("Failed to reset database: \(error)")
        }
    }
}

class CustomMigrationManager {
    func migrateStore(at storeURL: URL, to destinationURL: URL, targetModel: NSManagedObjectModel) throws {
        // Get the metadata from the store
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil)
        
        // Find the source model that matches the metadata
        guard let sourceModel = NSManagedObjectModel.mergedModel(from: [Bundle.main], forStoreMetadata: metadata) else {
            throw NSError(domain: "MigrationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to find source model"])
        }
        
        guard let mappingModel = CustomMigrationManager.mappingModel(from: sourceModel, to: targetModel) else {
            throw NSError(domain: "MigrationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to create mapping model"])
        }
        
        let manager = NSMigrationManager(sourceModel: sourceModel, destinationModel: targetModel)
        
        try manager.migrateStore(from: storeURL,
                                 sourceType: NSSQLiteStoreType,
                                 options: nil,
                                 with: mappingModel,
                                 toDestinationURL: destinationURL,
                                 destinationType: NSSQLiteStoreType,
                                 destinationOptions: nil)
    }
    
    static func mappingModel(from sourceModel: NSManagedObjectModel, to destinationModel: NSManagedObjectModel) -> NSMappingModel? {
        guard let customMapping = NSMappingModel(from: [Bundle.main], forSourceModel: sourceModel, destinationModel: destinationModel) else {
            return try? NSMappingModel.inferredMappingModel(forSourceModel: sourceModel, destinationModel: destinationModel)
        }
        return customMapping
    }
}
