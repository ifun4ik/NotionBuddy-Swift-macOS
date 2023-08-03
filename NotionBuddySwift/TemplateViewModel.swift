import SwiftUI
import CoreData

class TemplateViewModel: ObservableObject {
    @Published var template: Template
    @Published var templateFields: [TemplateFieldViewData] = []
    @Published var templateName: String = ""

    init(template: Template) {
        self.template = template
        self.templateName = template.name ?? ""
        let templateFieldsArray = fetchFields(for: template, in: template.managedObjectContext!)
        let sortedTemplateFields = templateFieldsArray.sorted(by: { $0.order < $1.order })
        self.templateFields = sortedTemplateFields.map {
            TemplateFieldViewData(
                name: $0.name ?? "",
                fieldType: $0.kind ?? "",
                defaultValue: $0.defaultValue ?? "",
                order: $0.order
            )
        }
        print("Initialized TemplateViewModel with fields: \(self.templateFields)")
    }

    func fetchFields(for template: Template, in managedObjectContext: NSManagedObjectContext) -> [TemplateField] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TemplateField")
        fetchRequest.predicate = NSPredicate(format: "template == %@", template)
        do {
            let fields = try managedObjectContext.fetch(fetchRequest) as! [TemplateField]
            return fields
        } catch {
            print("Failed to fetch fields: \(error)")
            return []
        }
    }
}
