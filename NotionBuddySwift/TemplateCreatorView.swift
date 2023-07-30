import SwiftUI
import SDWebImageSwiftUI
import SDWebImageSVGCoder
import CoreData

enum FieldKind: String, CaseIterable, Identifiable {
    case mandatory
    case optional
    case skip
    
    var id: String { self.rawValue }
}

class TemplateFieldViewData: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    let fieldType: String
    @Published var kind: FieldKind = .optional
    @Published var defaultValue: String
    @Published var order: Int16
    var options: [String]? = nil

    init(name: String, fieldType: String, defaultValue: String, order: Int16, options: [String]? = nil) {
        self.name = name
        self.fieldType = fieldType
        self.defaultValue = defaultValue
        self.order = order
        self.options = options
        if fieldType == "checkbox" || fieldType == "date" || fieldType == "email" || fieldType == "phone_number" || fieldType == "rich_text" || fieldType == "title" || fieldType == "url" || fieldType == "multi_select" || fieldType == "select" || fieldType == "status" {
            self.kind = .optional
        } else {
            self.kind = .skip
        }
    }
}

struct FieldRow: View {
    @ObservedObject var field: TemplateFieldViewData

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
                Picker(selection: $field.defaultValue, label: Text("Default Value")) {
                    ForEach(field.options ?? [], id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .disabled(field.kind == .skip)
            default:
                TextField("Default Value", text: .constant(""))
                    .disabled(true)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}

struct TemplateCreatorView: View {
    var database: Database
    @State private var templateName: String = ""
    @State var templateFields: [TemplateFieldViewData] = []
    @Binding var shouldDismiss: Bool
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Template Name:")
                    .font(.headline)
                TextField("Enter a name", text: $templateName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            
            Divider()
            
            List {
                ForEach(templateFields) { field in
                    FieldRow(field: field)
                }
                .onMove(perform: move)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .cornerRadius(8)
            
            Button(action: saveTemplate) {
                Text("Save Template")
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 40)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canSave())
            .help(templateName.isEmpty ? "Template name is required" : "")
        }
        
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            createFieldViewData(from: database)
        }
    }
    
    func createFieldViewData(from database: Database) {
        if let properties = database.properties {
            for (name, property) in properties {
                if let selectOptions = property.select?.options {
                    let options = selectOptions.map { $0.name }
                    let defaultValue = options.first ?? ""
                    templateFields.append(TemplateFieldViewData(name: name, fieldType: property.type, defaultValue: defaultValue, order: Int16(templateFields.count), options: options))
                } else if let statusOptions = property.status?.options {
                    let options = statusOptions.map { $0.name }
                    let defaultValue = options.first ?? ""
                    templateFields.append(TemplateFieldViewData(name: name, fieldType: property.type, defaultValue: defaultValue, order: Int16(templateFields.count), options: options))
                } else {
                    let defaultValue = ""
                    templateFields.append(TemplateFieldViewData(name: name, fieldType: property.type, defaultValue: defaultValue, order: Int16(templateFields.count)))
                }
            }
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        templateFields.move(fromOffsets: source, toOffset: destination)
        for (index, field) in templateFields.enumerated() {
            field.order = Int16(index)
        }
    }

    func saveTemplate() {
        // Create a new Template entity
        let newTemplate = Template(context: managedObjectContext)
        newTemplate.id = UUID()
        newTemplate.name = templateName
        newTemplate.order = Int16(templateFields.count)
        newTemplate.databaseId = database.id
        
        // Create TemplateField entities for each field
        for fieldViewData in templateFields {
            let newField = TemplateField(context: managedObjectContext)
            newField.id = fieldViewData.id
            newField.name = fieldViewData.name
            newField.defaultValue = fieldViewData.defaultValue
            newField.order = fieldViewData.order
            newField.kind = fieldViewData.kind.rawValue
            
            // Add the new field to the template
            newTemplate.addToFields(newField)
        }
        
        // Save the context
        do {
            try managedObjectContext.save()
            self.presentationMode.wrappedValue.dismiss()
            self.shouldDismiss = true
            logTemplates()
        } catch {
            print("Failed to save template: \(error)")
        }
    }
    
    func logTemplates() {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Template")
            do {
                if let results = try managedObjectContext.fetch(fetchRequest) as? [Template] {
                    for template in results {
                        print("Template Name: \(template.name ?? "")")
                        print("Order: \(template.order)")
                        print("Database ID: \(template.databaseId ?? "")")
                        print("Fields:")
                        if let fields = template.fields as? Set<TemplateField> {
                            for field in fields {
                                print("  Name: \(field.name ?? "")")
                                print("  Default Value: \(field.defaultValue ?? "")")
                                print("  Order: \(field.order)")
                                print("  Kind: \(field.kind ?? "")")
                            }
                        }
                    }
                }
            } catch let error as NSError {
                print("Could not fetch templates. \(error), \(error.userInfo)")
            }
        }

    
    func canSave() -> Bool {
        if templateName.isEmpty || !allMandatoryFieldsHaveDefaultValue() {
            return false
        }
        return true
    }
    
    func allMandatoryFieldsHaveDefaultValue() -> Bool {
        for field in templateFields {
            if field.kind == .mandatory && field.defaultValue.isEmpty {
                return false
            }
        }
        return true
    }
}
