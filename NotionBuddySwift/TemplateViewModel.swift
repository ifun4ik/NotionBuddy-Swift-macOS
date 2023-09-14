import SwiftUI
import CoreData

class EditableTemplateFieldViewData: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    var kind: String
    @Published var conflict: String?
    @Published var priority: String
    @Published var defaultValue: String
    @Published var order: Int16
    @Published var options: [String]? = nil

    init(templateField: TemplateField) {
        self.kind = templateField.kind ?? ""
        self.name = templateField.name ?? ""
        self.priority = templateField.priority ?? FieldPriority.optional.rawValue
        self.defaultValue = templateField.defaultValue ?? ""
        self.order = templateField.order
        self.options = templateField.options as? [String]

    checkFieldOptionsConflicts(with: templateField)}
        // Check for field options conflicts

    func checkFieldOptionsConflicts(with originalField: TemplateField) {
        // Assuming options are represented as an array of strings
        // This logic should be tailored to match the actual representation of field options
        guard let originalOptions = originalField.options as? [String],
              let currentOptions = self.options else { return }

        // Compare original options with current options and identify conflicts
        let conflicts = originalOptions.filter { !currentOptions.contains($0) }

        // If conflicts are detected, store a warning message
        if !conflicts.isEmpty {
            self.conflict = "Conflict"
        }
    }
    

}

class TemplateViewModel: ObservableObject {
    @Published var template: Template
    var templateFields: [EditableTemplateFieldViewData] = []
    @Published var templateName: String = ""

    init(template: Template) {
        self.template = template
        self.templateName = template.name ?? ""
        let templateFieldsArray = fetchFields(for: template, in: template.managedObjectContext!)
        let sortedTemplateFields = templateFieldsArray.sorted(by: { $0.order < $1.order })
        self.templateFields = sortedTemplateFields.map { EditableTemplateFieldViewData(templateField: $0) }
    }

    func fetchFields(for template: Template, in managedObjectContext: NSManagedObjectContext) -> [TemplateField] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TemplateField")
        fetchRequest.predicate = NSPredicate(format: "template == %@", template)
        do {
            let fields = try managedObjectContext.fetch(fetchRequest) as! [TemplateField]
            return fields
        } catch {
            print("Failed to fetch fields: \(error.localizedDescription)")
            return []
        }
    }
    
}

