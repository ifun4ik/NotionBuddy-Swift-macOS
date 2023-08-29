import CoreData
import SDWebImageSVGCoder
import SDWebImageSwiftUI
import SwiftUI

enum FieldPriority: String, CaseIterable, Identifiable {
    case mandatory
    case optional
    case skip
    var id: String { self.rawValue }
}

class TemplateFieldViewData: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    let kind: String
    @Published var priority: FieldPriority = .optional
    @Published var defaultValue: String
    @Published var order: Int16
    var options: [String]? = nil
    
    init(
        name: String,
        kind: String,
        defaultValue: String,
        order: Int16,
        options: [String]? = nil
    ) {
        self.name = name
        self.kind = kind
        self.defaultValue = defaultValue
        self.order = order
        self.options = options
        if kind == "checkbox" || kind == "date" || kind == "email" || kind == "phone_number"
            || kind == "rich_text" || kind == "title" || kind == "url"
            || kind == "multi_select" || kind == "select" || kind == "status"
        {
            self.priority = .optional
        }
        else {
            self.priority = .skip
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
                Text(field.kind)
                    .font(.body)
            }
            Picker("Field Priority", selection: $field.priority) {
                ForEach(FieldPriority.allCases) { kind in
                    Text(kind.rawValue.capitalized).tag(kind)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            switch field.kind {
                case "checkbox":
                    Toggle(
                        isOn: Binding(
                            get: { Bool(field.defaultValue) ?? false },
                            set: { field.defaultValue = String($0) }
                        )
                    ) {
                        Text("Default Value")
                    }
                    .disabled(field.priority == .skip)
                case "date":
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { Date() },
                            set: { field.defaultValue = "\($0)" }
                        )
                    )
                    .labelsHidden()
                    .disabled(field.priority == .skip)
                case "email", "phone_number", "rich_text", "title", "url":
                    TextField("Default Value", text: $field.defaultValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(field.priority == .skip)
                case "multi_select", "select", "status":
                    Picker("Default Value", selection: $field.defaultValue) {
                        ForEach(field.options ?? [], id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .disabled(field.priority == .skip)
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
    @State private var showAlert = false
    var database: Database
    @State private var templateName: String = ""
    @State var templateFields: [TemplateFieldViewData] = []
    @Binding var shouldDismiss: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @State private var existingNames: [String] = []
    
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
            existingNames = fetchExistingNames()
            createFieldViewData(from: database)
        }
    }
    
    func fetchExistingNames() -> [String] {
        let fetchRequest: NSFetchRequest<Template> = Template.fetchRequest()
        do {
            return try viewContext.fetch(fetchRequest).map { $0.name! }
        }
        catch {
            return []
        }
    }
    
    func createFieldViewData(from database: Database) {
        if let properties = database.properties {
            for (name, property) in properties {
                if let selectOptions = property.select?.options {
                    let options = selectOptions.map { $0.name }
                    let defaultValue = options.first ?? ""
                    templateFields.append(
                        TemplateFieldViewData(
                            name: name,
                            kind: property.type,
                            defaultValue: defaultValue,
                            order: Int16(templateFields.count),
                            options: options
                        )
                    )
                }
                else if let statusOptions = property.status?.options {
                    let options = statusOptions.map { $0.name }
                    let defaultValue = options.first ?? ""
                    templateFields.append(
                        TemplateFieldViewData(
                            name: name,
                            kind: property.type,
                            defaultValue: defaultValue,
                            order: Int16(templateFields.count),
                            options: options
                        )
                    )
                }
                else {
                    let defaultValue = ""
                    templateFields.append(
                        TemplateFieldViewData(
                            name: name,
                            kind: property.type,
                            defaultValue: defaultValue,
                            order: Int16(templateFields.count)
                        )
                    )
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
        if existingNames.contains(templateName) {
            showAlert = true
            return
        }
        // Fetching existing template names
        let existingTemplateNames = fetchExistingNames()
        // Checking for unique name and appending suffix if needed
        var uniqueTemplateName = templateName
        var counter = 2
        while existingTemplateNames.contains(uniqueTemplateName) {
            uniqueTemplateName = "\(templateName)-\(counter)"
            counter += 1
        }
        
        templateName = uniqueTemplateName
        let newTemplate = Template(context: viewContext)
        newTemplate.id = UUID()
        newTemplate.name = templateName
        newTemplate.order = Int16(templateFields.count)
        newTemplate.databaseId = database.id
        
        for fieldViewData in templateFields {
            let newField = TemplateField(context: viewContext)
            newField.id = fieldViewData.id
            newField.name = fieldViewData.name
            newField.defaultValue = fieldViewData.defaultValue
            newField.order = fieldViewData.order
            newField.priority = fieldViewData.priority.rawValue
            newField.kind = fieldViewData.kind
            newTemplate.addToFields(newField)
        }
        
        print("Saving new template:")
        print("  Name: \(newTemplate.name ?? "")")
        print("  Order: \(newTemplate.order)")
        print("  Database ID: \(newTemplate.databaseId ?? "")")
        print("  Fields:")
        for fieldViewData in templateFields {
            print("    Name: \(fieldViewData.name)")
            print("    Kind: \(fieldViewData.kind)")
            print("    Priority: \(fieldViewData.priority.rawValue)")
            print("    Default Value: \(fieldViewData.defaultValue)")
            print("    Order: \(fieldViewData.order)")
            if let options = fieldViewData.options {
                print("    Options: \(options.joined(separator: ", "))")
            }
        }
        
        DispatchQueue.global()
            .async {
                do {
                    try viewContext.save()
                    DispatchQueue.main.async {
                        self.presentationMode.wrappedValue.dismiss()
                        self.shouldDismiss = true
                    }
                }
                catch {
                    DispatchQueue.main.async {
                        self.showAlert = true
                    }
                }
            }
    }
    
    func logTemplates() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Template")
        do {
            if let results = try viewContext.fetch(fetchRequest) as? [Template] {
                for template in results {
                    print("Template Name: \(template.name ?? "")")
                    print("Order: \(template.order)")
                    print("Database ID: \(template.databaseId ?? "")")
                    print("Fields:")
                    if let fields = template.fields as? Set<TemplateField> {
                        for field in fields {
                            print("  Name: \(field.name ?? "")")
                            print(
                                "  Default Value: \(field.defaultValue ?? "")"
                            )
                            print("  Order: \(field.order)")
                            print("  Kind: \(field.kind ?? "")")
                        }
                    }
                }
            }
        }
        
        catch let error as NSError {
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
            if field.priority == .mandatory && field.defaultValue.isEmpty {
                return false
            }
        }
        return true
    }
}
