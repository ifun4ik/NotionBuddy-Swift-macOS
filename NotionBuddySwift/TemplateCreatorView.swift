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
    @Published var defaultValues: Set<String> = []
    @Published var order: Int16
    @Published var selectedValues: Set<String> = [] 
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
    @State private var showMultiSelect = false

    var body: some View {
        HStack{
            Image(systemName: "line.horizontal.3")
                .foregroundColor(.gray)
                .padding(.trailing, 10)
            
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
                case "select", "status":
                    Picker("Default Value", selection: $field.defaultValue) {
                        ForEach(field.options ?? [], id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .disabled(field.priority == .skip)
                    
                case "multi_select":
                    Button(action: { showMultiSelect.toggle() }) {
                        HStack {
                            Text("Select Options: \(field.selectedValues.joined(separator: ", "))")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    .sheet(isPresented: $showMultiSelect) {
                        MultiSelectView(options: field.options ?? [], selectedOptions: $field.selectedValues)
                    }
                    
                default:
                    TextField("Default Value", text: .constant(""))
                        .disabled(true)
                }
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
                ForEach(templateFields, id: \.id) { field in
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
            var skipPriorityFields: [TemplateFieldViewData] = []

            for (name, property) in properties {
                var options: [String] = []

                switch property.type {
                case "select":
                    options = property.select?.options.map { $0.name } ?? []
                case "multi_select":
                    options = property.multi_select?.options.map { $0.name } ?? []
                case "status":
                    options = property.status?.options.map { $0.name } ?? []
                default:
                    break
                }

                let defaultValue = options.first ?? ""
                let fieldViewData = TemplateFieldViewData(
                    name: name,
                    kind: property.type,
                    defaultValue: defaultValue,
                    order: Int16(templateFields.count),
                    options: options.isEmpty ? nil : options
                )

                if fieldViewData.priority == .skip {
                    skipPriorityFields.append(fieldViewData)
                } else {
                    templateFields.append(fieldViewData)
                }
            }

            // Append the .skip priority fields at the end
            templateFields.append(contentsOf: skipPriorityFields)
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
            newTemplate.databaseName = database.name

        
        for fieldViewData in templateFields {
            let newField = TemplateField(context: viewContext)
            newField.id = fieldViewData.id
            newField.name = fieldViewData.name
            newField.defaultValue = fieldViewData.defaultValue
            newField.order = fieldViewData.order
            newField.priority = fieldViewData.priority.rawValue
            newField.kind = fieldViewData.kind
            
            if fieldViewData.kind == "multi_select" {
                let selectedValues = Array(fieldViewData.selectedValues)
                if let jsonData = try? JSONEncoder().encode(selectedValues) {
                    newField.defaultValue = String(data: jsonData, encoding: .utf8) ?? ""
                }
            } else {
                newField.defaultValue = fieldViewData.defaultValue
            }
            
            if let options = fieldViewData.options {
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: options, requiringSecureCoding: false) as NSData
                    newField.options = data
                } catch {
                    print("Failed to archive options: \(error)")
                }
            }

            newTemplate.addToFields(newField)
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


struct MultiSelectView: View {
    let options: [String]
    @Binding var selectedOptions: Set<String>

    var body: some View {
        List(options, id: \.self) { option in
            HStack {
                Text(option)
                Spacer()
                if selectedOptions.contains(option) {
                    Image(systemName: "checkmark")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if selectedOptions.contains(option) {
                    selectedOptions.remove(option)
                } else {
                    selectedOptions.insert(option)
                }
            }
        }
    }
}
