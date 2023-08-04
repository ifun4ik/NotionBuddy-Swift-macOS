import SwiftUI
import CoreData

class EditableTemplateFieldViewData: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    let fieldType: String
    @Published var kind: FieldKind
    @Published var defaultValue: String
    @Published var order: Int16
    var options: [String]? = nil

    init(templateField: TemplateField) {
        self.name = templateField.name ?? ""
        self.fieldType = templateField.kind ?? ""
        self.defaultValue = templateField.defaultValue ?? ""
        self.order = templateField.order
        self.kind = FieldKind(rawValue: templateField.kind ?? "") ?? .optional
    }
}

class TemplateViewModel: ObservableObject {
    @Published var template: Template
    @Published var templateFields: [EditableTemplateFieldViewData] = []
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
            print("Failed to fetch fields: \(error)")
            return []
        }
    }
}

struct EditFieldRow: View {
    @ObservedObject var field: EditableTemplateFieldViewData

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Field Name:")
                    .font(.headline)
                Text(field.name)
                    .font(.body)
            }
            HStack {
                Text("Field Type:")
                    .font(.headline)
                Text(field.fieldType)
                    .font(.body)
            }
            
            Picker("Field Priority", selection: $field.kind) {
                ForEach(FieldKind.allCases) { kind in
                    Text(kind.rawValue.capitalized).tag(kind)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            switch field.fieldType {
            case "checkbox":
                Toggle(isOn: Binding(get: {
                    Bool(field.defaultValue) ?? false
                }, set: {
                    field.defaultValue = String($0)
                })) {
                    Text("Default Value")
                }
                .disabled(field.kind == .skip)
            case "date":
                DatePicker("", selection: Binding(get: {
                    Date()
                }, set: {
                    field.defaultValue = "\($0)"
                }))
                    .labelsHidden()
                    .disabled(field.kind == .skip)
            case "email", "phone_number", "rich_text", "title", "url":
                TextField("Default Value", text: $field.defaultValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(field.kind == .skip)
            case "multi_select", "select", "status":
                Picker("Default Value", selection: $field.defaultValue) {
                    ForEach(field.options ?? [], id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .disabled(field.kind == .skip)
            default:
                TextField("Default Value", text: $field.defaultValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(field.kind == .skip)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}
