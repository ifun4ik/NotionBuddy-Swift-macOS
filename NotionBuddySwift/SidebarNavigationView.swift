//import SwiftUI
//
//struct SidebarNavigationView: View {
//    @ObservedObject var sessionManager: SessionManager
//    @Environment(\.managedObjectContext) private var managedObjectContext
//    @State private var selection: NavigationItem? = .home
//
//    enum NavigationItem: Hashable {
//        case home
//        case templates
//    }
//
//    var body: some View {
//        NavigationView {
//            List(selection: $selection) {
//                NavigationLink(destination: MainView(sessionManager: sessionManager)) {
//                    Label("Home", systemImage: "house")
//                }
//                .tag(NavigationItem.home)
//
//                if !sessionManager.accounts.isEmpty {
//                    NavigationLink(destination: TemplateNavigatorView(managedObjectContext: managedObjectContext, sessionManager: sessionManager)) {
//                        Label("Templates", systemImage: "doc.text")
//                    }
//                    .tag(NavigationItem.templates)
//                }
//            }
//            .listStyle(.sidebar)
//            .navigationTitle("Navigation")
//
//            Text("Select a navigation item from the sidebar")
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//        }
//    }
//}
