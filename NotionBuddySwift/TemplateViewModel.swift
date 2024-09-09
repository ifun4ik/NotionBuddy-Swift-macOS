import SwiftUI
import CoreData

class EditableTemplateFieldViewData: ObservableObject, Identifiable {
    let id = UUID()
    var name: String
    var kind: String
    @Published var conflict: String?
    @Published var priority: String
    @Published var defaultValue: String
    @Published var order: Int16
    @Published var options: [String]? = nil
    @Published var selectedValues: Set<String> = []
    @Published var relationOptions: [String: String]?

    init(templateField: TemplateField) {
        self.kind = templateField.kind ?? ""
        self.name = templateField.name ?? ""
        self.priority = templateField.priority ?? FieldPriority.optional.rawValue
        self.order = templateField.order

        if let optionsData = templateField.options as? Data {
            do {
                if let optionsDictionary = try? JSONDecoder().decode([String: String].self, from: optionsData) {
                    self.options = Array(optionsDictionary.values)
                    self.relationOptions = optionsDictionary
                } else {
                    self.options = try JSONDecoder().decode([String].self, from: optionsData)
                }
            } catch {
                print("Error decoding options data: \(error)")
                self.options = []
            }
        } else {
            self.options = []
        }

        // Only set default value if it's not empty and not a dropdown field
        if let defaultValue = templateField.defaultValue, !defaultValue.isEmpty,
           !["select", "multi_select", "status", "relation"].contains(kind) {
            self.defaultValue = defaultValue
        } else {
            self.defaultValue = ""
        }

        if kind == "multi_select", let defaultValue = templateField.defaultValue {
            if let jsonData = defaultValue.data(using: .utf8) {
                do {
                    let decodedValues = try JSONDecoder().decode([String].self, from: jsonData)
                    self.selectedValues = Set(decodedValues)
                } catch {
                    print("Failed to decode selected multi_select values: \(error)")
                }
            }
        }
    }

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

    func setPriorityBasedOnKind() {
        if kind == "checkbox" || kind == "date" || kind == "email" || kind == "phone_number"
            || kind == "rich_text" || kind == "title" || kind == "url"
            || kind == "multi_select" || kind == "select" || kind == "status" {
            self.priority = FieldPriority.optional.rawValue
        } else {
            self.priority = FieldPriority.skip.rawValue
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
        self.templateFields = sortedTemplateFields.map { field in
            EditableTemplateFieldViewData(templateField: field)
        }
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

