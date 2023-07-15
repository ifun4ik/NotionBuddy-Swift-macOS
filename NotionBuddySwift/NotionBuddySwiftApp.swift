import SwiftUI

@main
struct NotionBuddyApp : App {
//MARK: This part wipes user defaults each time the app being launched
    init() {
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
        }
    
    var body : some Scene {
        WindowGroup{
            LoginView()
                .frame(minWidth : 552 , maxWidth : 552 , minHeight : 612 , maxHeight : 612)
        }.windowStyle(HiddenTitleBarWindowStyle())
         .windowToolbarStyle(UnifiedCompactWindowToolbarStyle())
         .commands{
             CommandGroup(replacing : .newItem){} // Disable the New Window command
         }
    }
}
