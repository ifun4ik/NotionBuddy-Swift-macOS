import Foundation
import SwiftUI
import CoreData

struct TemplateNavigatorView: View {
    @FetchRequest(entity: Template.entity(), sortDescriptors: [])
    var templates: FetchedResults<Template>
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var showDatabaseNavigatorView = false
    @State private var showEditTemplateView = false
    @State private var selectedTemplate: Template? = nil
    @State private var shouldDismiss = false
    @State private var showingEditView = false

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
                        Text(template.name ?? "Unnamed Template")
                        .contextMenu {
                            Button(action: {
                                self.selectedTemplate = template
                                self.showEditTemplateView = true
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
    .sheet(isPresented: $showEditTemplateView, onDismiss: {
        self.selectedTemplate = nil
    }) {
        if let templateToEdit = self.selectedTemplate {
            EditTemplateView(template: templateToEdit).environment(\.managedObjectContext, self.managedObjectContext)
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
