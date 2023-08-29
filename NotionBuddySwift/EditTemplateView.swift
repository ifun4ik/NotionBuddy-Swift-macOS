import SwiftUI
import SDWebImageSwiftUI
import SDWebImageSVGCoder
import CoreData

struct EditTemplateView: View {
    @StateObject var viewModel: TemplateViewModel
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    @State private var database: Database?
    @State private var conflicts: [String] = []

    
    /// Compares the fetched Notion database properties with the existing template
    func compareFetchedDatabaseWithTemplate(fetchedData: [String: Any]) {
        // Reset conflicts
        conflicts.removeAll()
        
        print("Function compareFetchedDatabaseWithTemplate called.")
        print("Fetched Data: \(fetchedData)")
        
        // Loop through fetched data and compare with template
        for (key, fetchedValue) in fetchedData {
            print("Checking fetched key: \(key)")
            if let templateField = viewModel.templateFields.first(where: { $0.name == key }) {
                if let fetchedDict = fetchedValue as? [String: Any] {
                    if templateField.kind != (fetchedDict["type"] as? String) {
                        conflicts.append("Kind mismatch for \(key). Template: \(templateField.kind ?? "Unknown"), Fetched: \(String(describing: fetchedDict["type"]))")
                    }
                    if let fetchedOptions = fetchedDict["options"] as? [[String: Any]] {
                        let templateOptions = templateField.options ?? []
                        if !Set(templateOptions).isSubset(of: Set(fetchedOptions.compactMap { $0["name"] as? String })) {
                            conflicts.append("Options mismatch for \(key).")
                        }
                    }
                }
            } else {
                conflicts.append("\(key) is not present in the template.")
            }
        }
        
        // Loop through template fields and compare with fetched data
        for templateField in viewModel.templateFields {
            if fetchedData[templateField.name] == nil {
                conflicts.append("\(templateField.name) is not present in the fetched data.")
            } else if let fetchedDict = fetchedData[templateField.name] as? [String: Any] {
                let fetchedOptions = (fetchedDict["options"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
                let templateOptions = templateField.options ?? []
                if !Set(fetchedOptions ?? []).isSubset(of: Set(templateOptions)) {
                    conflicts.append("New options added in \(templateField.name).")
                }
            }
        }
        
        print("Conflicts found: \(conflicts)")
    }
var accessToken: String

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Template Name:")
                    .font(.headline)
                TextField("Enter a name", text: $viewModel.templateName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 8)
            
            // Section to display conflicts
            if !conflicts.isEmpty {
                Section(header: Text("Conflicts")) {
                    List(conflicts, id: \.self) { conflict in
                        Text(conflict)
                            .foregroundColor(.red)
                    }
                }
            }
}
            .padding(.horizontal, 16)

            Divider()

            List {
              ForEach(viewModel.templateFields, id: \.id) { field in
                EditFieldRow(field: field)
              }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .cornerRadius(8)
            .frame(minHeight: 400)

            Button(action: updateTemplate) {
                Text("Update Template")
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 40)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canSave())
            .help(viewModel.templateName.isEmpty ? "Template name is required" : "")

            if !conflicts.isEmpty {
                Text("Conflicts Detected:")
                    .font(.headline)
                ForEach(conflicts, id: \.self) { conflict in
                    Text(conflict)
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            fetchDatabase()
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        viewModel.templateFields.move(fromOffsets: source, toOffset: destination)
        for (index, field) in viewModel.templateFields.enumerated() {
            field.order = Int16(index)
        }
    }

    func updateTemplate() {
        viewModel.template.name = viewModel.templateName
        viewModel.template.order = Int16(viewModel.templateFields.count)

        if let oldFields = viewModel.template.fields as? Set<TemplateField> {
            for oldField in oldFields {
                managedObjectContext.delete(oldField)
            }
        }

        for fieldViewData in viewModel.templateFields {
            let newField = TemplateField(context: managedObjectContext)
            newField.id = fieldViewData.id
            newField.name = fieldViewData.name
            newField.defaultValue = fieldViewData.defaultValue
            newField.order = fieldViewData.order
            newField.kind = fieldViewData.kind
            newField.priority = fieldViewData.priority
            
            viewModel.template.addToFields(newField)
        }

        do {
            try managedObjectContext.save()
            self.presentationMode.wrappedValue.dismiss()
        } catch {
            print("Failed to update template: \(error)")
        }
    }

    func canSave() -> Bool {
        if viewModel.templateName.isEmpty || !allMandatoryFieldsHaveDefaultValue() {
            return false
        }
        return true
    }

    func allMandatoryFieldsHaveDefaultValue() -> Bool {
        for field in viewModel.templateFields {
            if field.kind == "mandatory" && field.defaultValue.isEmpty {
                return false
            }
        }
        return true
    }

    func fetchDatabase() {
        guard let databaseId = viewModel.template.databaseId,
              let url = URL(string: "https://api.notion.com/v1/databases/\(databaseId)") else {
            print("Invalid URL or database ID.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("2021-05-13", forHTTPHeaderField: "Notion-Version")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to fetch database properties. Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("Failed to retrieve database properties.")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let properties = json["properties"] as? [String: Any] {
                    print(properties) // Printing only the properties of the database
                    compareFetchedDatabaseWithTemplate(fetchedData: properties)
                }
            } catch {
                print("Unexpected error: \(error).")
            }
        }.resume()
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
                Text(field.kind)
                    .font(.body)
            }
            
            Picker("Field Priority", selection: $field.priority) {
                ForEach(FieldPriority.allCases) { priority in
                    Text(priority.rawValue.capitalized).tag(priority)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            switch field.kind {
            case "checkbox":
                Toggle(isOn: Binding(get: {
                    Bool(field.defaultValue) ?? false
                }, set: {
                    field.defaultValue = String($0)
                })) {
                    Text("Default Value")
                }
                .disabled(field.priority == "skip")
            case "date":
                DatePicker("", selection: Binding(get: {
                    Date()
                }, set: {
                    field.defaultValue = "\($0)"
                }))
                    .labelsHidden()
                    .disabled(field.priority == "skip")
            case "email", "phone_number", "rich_text", "title", "url":
                TextField("Default Value", text: $field.defaultValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(field.priority == "skip")
            case "multi_select", "select", "status":
                Picker("Default Value", selection: $field.defaultValue) {
//                  ForEach(pickerValues ?? ["No Options"], id: \.self) { option in
//                    Text(option).tag(option)
//                  }
                    Text(field.defaultValue).tag(field.defaultValue)
                }
                .disabled(field.priority == "skip")

                // Explicitly set selection to match default value
                .onAppear {
                    field.defaultValue = field.defaultValue
                    
                  }
            default:
                TextField("Default Value", text: $field.defaultValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(field.priority == "skip")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}
