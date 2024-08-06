import SwiftUI
import CoreData

class TemplatesListViewModel: ObservableObject {
    @Published var templates: [Template] = []
    
    private let sessionManager: SessionManager
    private let managedObjectContext: NSManagedObjectContext
    
    init(sessionManager: SessionManager, context: NSManagedObjectContext) {
        self.sessionManager = sessionManager
        self.managedObjectContext = context
        fetchTemplates()
    }
    
    func fetchTemplates() {
        let request: NSFetchRequest<Template> = Template.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Template.order, ascending: true)]
        
        do {
            templates = try managedObjectContext.fetch(request)
        } catch {
            print("Error fetching templates: \(error)")
        }
    }
    
    func deleteTemplate(at offsets: IndexSet) {
        for index in offsets {
            let template = templates[index]
            managedObjectContext.delete(template)
        }
        saveContext()
        fetchTemplates()
    }
    
    func moveTemplate(from source: IndexSet, to destination: Int) {
        var revisedItems = templates
        revisedItems.move(fromOffsets: source, toOffset: destination)
        for (index, template) in revisedItems.enumerated() {
            template.order = Int16(index)
        }
        saveContext()
        fetchTemplates()
    }
    
    private func saveContext() {
        do {
            try managedObjectContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}
