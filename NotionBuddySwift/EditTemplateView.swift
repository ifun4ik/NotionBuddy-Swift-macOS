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
    var accessToken: String

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Template Name:")
                    .font(.headline)
                TextField("Enter a name", text: $viewModel.templateName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 8)
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
              let url = URL(string: "https://api.notion.com/v1/databases/33a44fbb00ac4249bb386829e222b5f1/query") else {
            return
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("2021-05-13", forHTTPHeaderField: "Notion-Version")
        print(request)
        print(accessToken)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to fetch database. Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("Failed to retrieve database.")
                return
            }

            do {
                let decodedData = try JSONDecoder().decode(DatabasesResponse.self, from: data)
                DispatchQueue.main.async {
                    self.database = decodedData.results.first
                    self.compareDatabaseWithTemplate()
                }
                print(decodedData)
            } catch {
                print("Failed to decode database. Error: \(error.localizedDescription)")
            }
        }.resume()
    }

    func compareDatabaseWithTemplate() {
        guard let databaseProperties = database?.properties else {
            return
        }

        var conflicts: [String] = []
        for fieldViewData in viewModel.templateFields {
            if let databaseProperty = databaseProperties[fieldViewData.name],
               databaseProperty.type != fieldViewData.kind {
                conflicts.append("Field '\(fieldViewData.name)' has different types in database and template.")
            }
        }
        self.conflicts = conflicts
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
                .disabled(field.kind == "skip")
            case "date":
                DatePicker("", selection: Binding(get: {
                    Date()
                }, set: {
                    field.defaultValue = "\($0)"
                }))
                    .labelsHidden()
                    .disabled(field.kind == "skip")
            case "email", "phone_number", "rich_text", "title", "url":
                TextField("Default Value", text: $field.defaultValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(field.kind == "skip")
            case "multi_select", "select", "status":
                Picker("Default Value", selection: $field.defaultValue) {
                    ForEach(field.options ?? [], id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .disabled(field.kind == "skip")
            default:
                TextField("Default Value", text: $field.defaultValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(field.kind == "skip")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}
