import Foundation
import SwiftUI
import CoreData

struct TemplateNavigatorView: View {
    @FetchRequest(entity: Template.entity(), sortDescriptors: [])
    var templates: FetchedResults<Template>
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var showDatabaseNavigatorView = false
    @State private var selectedTemplate: Template? = nil
    @State private var shouldDismiss = false
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
                        NavigationLink(destination: EditTemplateView(template: template).environment(\.managedObjectContext, self.managedObjectContext)) {
                            Text(template.name ?? "Unnamed Template")
                        }
                        .contextMenu {
                            Button(action: {
                                self.selectedTemplate = template
                            }) {
                                Text("Edit")
                                Image(systemName: "pencil")
                            }
                            
                            Button(action: {
                                self.managedObjectContext.delete(template)
                                do {
                                    try self.managedObjectContext.save()
                                } catch {
                                    // handle the Core Data error
                                }
                            }) {
                                Text("Delete")
                                Image(systemName: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteTemplate)
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
            FixedSizeSheet(width: 400, height: 400) {
                DatabaseNavigatorView(accessToken: accessToken, shouldDismiss: self.$shouldDismiss)
            }
        }

    }
    
    private func deleteTemplate(at offsets: IndexSet) {
        for index in offsets {
            let template = templates[index]
            managedObjectContext.delete(template)
        }
        do {
            try managedObjectContext.save()
        } catch {
            // handle the Core Data error
        }
    }
}

struct EditTemplateView: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    @ObservedObject var template: Template
    
    var body: some View {
        Form {
            TextField("Template Name", text: $template.name.bound)
            // Add other fields as needed
        }
        .navigationTitle("Edit Template")
        .toolbar {
            ToolbarItem {
                Button(action: {
                    do {
                        try managedObjectContext.save()
                    } catch {
                        // handle the Core Data error
                    }
                }) {
                    Text("Save")
                }
            }
        }
    }
}

struct FixedSizeSheet<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: width, height: height)
    }
}

extension Optional where Wrapped == String {
    var bound: String {
        get { return self ?? "" }
        set { self = newValue }
    }
}
