//
//  NotionBuddySwiftApp.swift
//  NotionBuddySwift
//
//  Created by Harry on 14.06.2023.
//

import SwiftUI

@main
struct NotionBuddySwiftApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
