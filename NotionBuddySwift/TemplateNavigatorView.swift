import Foundation
import SwiftUI
import CoreData

struct TemplateNavigatorView: View {
    @FetchRequest(entity: Template.entity(), sortDescriptors: [])
    var templates: FetchedResults<Template>
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var showDatabaseNavigatorView = false
    var accessToken: String
    
    var body: some View {
        VStack {
            if templates.isEmpty {
                Text("No templates were found. Try creating a new one.")
                Button("Create Template") {
                    showDatabaseNavigatorView = true
                }
            } else {
                List {
                    ForEach(templates) { template in
                        NavigationLink(destination: Text("Template Detail View")) {
                            Text(template.name ?? "Unnamed Template")
                        }
                    }
                }
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem {
                Button(action: {
                    showDatabaseNavigatorView = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showDatabaseNavigatorView) {
            DatabaseNavigatorView(accessToken: accessToken)
        }
    }
}
