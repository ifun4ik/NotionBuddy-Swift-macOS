import SwiftUI
import SDWebImageSwiftUI
import SDWebImageSVGCoder
import CoreData


extension Array where Element == String {
    func toNSData() -> NSData? {
        do {
            let data = try JSONSerialization.data(withJSONObject: self, options: [])
            return data as NSData
        } catch {
            print("Failed to convert array to NSData: \(error)")
            return nil
        }
    }
}

struct EditTemplateView: View {
    @StateObject var viewModel: TemplateViewModel
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    @State private var database: Database?
    @State private var conflicts: [String] = []
    @State private var fetchedProps: [String : Any] = [:]
    @State private var forceRefresh: Bool = false
    
    @State private var draggedItem: EditableTemplateFieldViewData?
    @State private var position: CGFloat = 0
    @State private var currentHoveredIndex: Int? = nil
    @State private var dropPosition: Int? = nil 

    /// Compares the fetched Notion database properties with the existing template
    func compareFetchedDatabaseWithTemplate(fetchedData: [String: Any], withFields fields: [EditableTemplateFieldViewData]) {
        // Clear the conflicts
        conflicts.removeAll()
        
        // Loop through fetched data and compare with template
        for (key, fetchedValue) in fetchedData {
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
    
    func resetTemplateToNotion() {
        // 1. Delete old fields from the managedObjectContext
        if let oldFields = viewModel.template.fields as? Set<TemplateField> {
            for oldField in oldFields {
                managedObjectContext.delete(oldField)
                print("🗑️ Removed \(oldField.name ?? "Unknown Field")")
            }
        }
        
        // 2. Save the context after deleting
        do {
            try managedObjectContext.save()
        } catch {
            print("Failed to delete old fields: \(error)")
        }
        
        // 3. Create new fields based on fetchedProps
        var newTemplateFields: [EditableTemplateFieldViewData] = []
        
        for (key, fetchedValue) in fetchedProps {
            if let fetchedDict = fetchedValue as? [String: Any] {
                let kind = fetchedDict["type"] as? String ?? ""
                let options = (fetchedDict["options"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
                
                var defaultValue: String = ""
                if let firstOption = options?.first {
                    defaultValue = firstOption
                }
                
                let newField = EditableTemplateFieldViewData(templateField: TemplateField(context: managedObjectContext))
                newField.kind = kind
                newField.name = key
                newField.options = options
                newField.setPriorityBasedOnKind()
                
                // Logic to maintain disabled fields
                if let existingField = viewModel.templateFields.first(where: { $0.name == key }) {
                    newField.defaultValue = existingField.defaultValue
                } else {
                    newField.defaultValue = defaultValue
                }
                
                if let options = newField.options, !options.contains(where: { $0 == newField.defaultValue }) {
                    newField.defaultValue = options.first ?? ""
                }
                newTemplateFields.append(newField)
            } else if let fetchedArray = fetchedValue as? [String] {
                // Handle fields represented as arrays
                let newField = EditableTemplateFieldViewData(templateField: TemplateField(context: managedObjectContext))
                newField.kind = "select"  // Assuming fields represented as arrays are of kind "select"
                newField.name = key
                newField.options = fetchedArray
                newField.setPriorityBasedOnKind()
                
                // Logic to maintain disabled fields
                if let existingField = viewModel.templateFields.first(where: { $0.name == key }) {
                    newField.defaultValue = existingField.defaultValue
                } else {
                    newField.defaultValue = fetchedArray.first ?? ""
                }
                
                if let options = newField.options, !options.contains(where: { $0 == newField.defaultValue }) {
                    newField.defaultValue = options.first ?? ""
                }
                newTemplateFields.append(newField)
            }
        }
        
        
        // 4. Update the viewModel.templateFields with our new fields
        viewModel.templateFields = newTemplateFields

        // 5. Save the context after adding new fields
        managedObjectContext.perform {
            do {
                try managedObjectContext.save()
                conflicts.removeAll()
                DispatchQueue.main.async {
                    self.forceRefresh.toggle()
                }
            } catch {
                print("Failed to reset template: \(error)")
            }
        }
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
            }
            .padding(.horizontal, 16)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.templateFields.enumerated()), id: \.element.id) { index, field in
                        EditFieldRow(field: field, json: fetchedProps)
                            .background(self.backgroundForIndex(index: index))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .frame(idealWidth: .infinity)
                            .onDrag {
                                self.draggedItem = field
                                return NSItemProvider(object: "\(field.id)" as NSString)
                            }
                            .onDrop(of: [kUTTypeText as String], delegate: DropViewDelegate(item: field, items: $viewModel.templateFields, draggedItem: $draggedItem, position: $position, hoveredIndex: $currentHoveredIndex, dropPosition: $dropPosition))
                            .overlay(VStack {
                                if dropPosition == index {
                                    Divider().background(Color.blue).padding([.leading, .trailing])
                                }
                                Spacer()
                            })
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .frame(idealHeight: 500)

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
                Button(action: resetTemplateToNotion) {
                    Text("Reset Template")
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 40)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
            }

            if !conflicts.isEmpty {
                Text("Conflicts Detected:")
                    .font(.headline)
                ForEach(conflicts, id: \.self) { conflict in
                    Text(conflict)
                }
            }
        }
        .id(forceRefresh)
        .onAppear {
            fetchDatabase(gottaCheck: true)
            sortTemplateFields()
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    func move(from source: IndexSet, to destination: Int) {
        viewModel.templateFields.move(fromOffsets: source, toOffset: destination)
        for (index, field) in viewModel.templateFields.enumerated() {
            field.order = Int16(index)
        }
        saveContext()
    }

    func updateTemplate() {
        viewModel.template.name = viewModel.templateName
        viewModel.template.order = Int16(viewModel.templateFields.count)

        if let oldFields = viewModel.template.fields as? Set<TemplateField> {
            for oldField in oldFields {
                managedObjectContext.delete(oldField)
            }
        }

        for (index, fieldViewData) in viewModel.templateFields.enumerated() {
            let newField = TemplateField(context: managedObjectContext)
            newField.id = fieldViewData.id
            newField.name = fieldViewData.name
            newField.defaultValue = fieldViewData.defaultValue
            newField.order = Int16(index)
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

    func fetchDatabase(gottaCheck: Bool) {
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
                    DispatchQueue.main.async {
                        if gottaCheck{
                            self.compareFetchedDatabaseWithTemplate(fetchedData: properties, withFields: viewModel.templateFields)
                        }
                        self.fetchedProps = properties
                        self.fetchOptions(fetchedData: properties)
                    }
                }
            } catch {
                print("Unexpected error: \(error).")
            }
        }.resume()
    }
    
    func fetchOptions(fetchedData: [String: Any]) {
        for (key, fetchedValue) in fetchedData {
            if let templateField = viewModel.templateFields.first(where: {
                  $0.name == key && ($0.kind == "select" || $0.kind == "multiselect" || $0.kind == "status")
                }) {
                if let fetchedDict = fetchedValue as? [String: Any] {
                    if let selectDict = fetchedDict["select"] as? [String: Any],
                       let options = selectDict["options"] as? [[String: Any]] {
                        let optionNames = options.compactMap({ $0["name"] as? String })
                        templateField.options = optionNames

                        // Ensure the default value exists in options
                        if !optionNames.contains(templateField.defaultValue) {
                            templateField.defaultValue = optionNames.first ?? ""
                        }
                    } else {
                        print("No options found in fetched dict")
                    }
                } else {
                    print("Fetched value is not a dictionary")
                }
                fetchedProps[key] = templateField.options
            }
        }
    }
    
    func backgroundForIndex(index: Int) -> Color {
        return index % 2 == 0 ? Color(NSColor.windowBackgroundColor) : Color(NSColor.controlBackgroundColor)
    }

    
    func sortTemplateFields() {
        viewModel.templateFields.sort(by: { $0.order < $1.order })
    }
    
    func saveContext() {
        do {
            try managedObjectContext.save()
        } catch {
            print("Failed to save context after reordering: \(error)")
        }
    }

}

struct EditFieldRow: View {
    @ObservedObject var field: EditableTemplateFieldViewData
    @State var json: [String: Any]

    var body: some View {
        HStack {
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
                    ForEach(FieldPriority.allCases) { priority in
                        Text(priority.rawValue.capitalized).tag(priority)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(field.priority == FieldPriority.skip.rawValue)
                
                switch field.kind {
                case "checkbox":
                    Toggle(isOn: Binding(get: {
                        Bool(field.defaultValue) ?? false
                    }, set: {
                        field.defaultValue = String($0)
                    })) {
                        Text("Default Value")
                    }
                    .disabled(field.priority == FieldPriority.skip.rawValue)
                case "date":
                    DatePicker("", selection: Binding(get: {
                        Date()
                    }, set: {
                        field.defaultValue = "\($0)"
                    }))
                    .labelsHidden()
                    .disabled(field.priority == FieldPriority.skip.rawValue)
                case "email", "phone_number", "rich_text", "title", "url":
                    TextField("Default Value", text: $field.defaultValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(field.priority == FieldPriority.skip.rawValue)
                case "multi_select", "select", "status":
                    if let jsonOptions = json[field.name] as? [String: Any], let options = jsonOptions["options"] as? [[String: Any]] {
                        let optionNames = options.compactMap { $0["name"] as? String }
                        ForEach(optionNames, id: \.self) { option in
                            Text("Option: \(option)")
                        }
                        Picker("Default Value", selection: $field.defaultValue) {
                            ForEach(field.options ?? [], id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .disabled(field.priority == FieldPriority.skip.rawValue)
                    } else {
                        Picker("Default Value", selection: $field.defaultValue) {
                            ForEach(field.options ?? [], id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .disabled(field.priority == FieldPriority.skip.rawValue)
                    }
                default:
                    TextField("Default Value", text: $field.defaultValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(field.priority == FieldPriority.skip.rawValue)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
    }
}


struct DropViewDelegate: DropDelegate {
    let item: EditableTemplateFieldViewData
    @Binding var items: [EditableTemplateFieldViewData]
    @Binding var draggedItem: EditableTemplateFieldViewData?
    @Binding var position: CGFloat
    @Binding var hoveredIndex: Int?
    @Binding var dropPosition: Int?  // Added to compute the drop position

    func performDrop(info: DropInfo) -> Bool {
        if let fromIndex = items.firstIndex(where: { $0.id == draggedItem?.id }),
           let toIndex = items.firstIndex(where: { $0.id == item.id }) {
            withAnimation {
                items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex)
            }
        }
        draggedItem = nil
        hoveredIndex = nil
        dropPosition = nil  // Resetting the drop position
        return true
    }

    func dropEntered(info: DropInfo) {
        if let _ = info.itemProviders(for: [kUTTypeText as String]).first {
            let toIndex = items.firstIndex { $0.id == item.id }!
            dropPosition = toIndex
        }
    }


    func dropExited(info: DropInfo) {
        dropPosition = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
