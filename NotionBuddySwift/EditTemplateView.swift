import SwiftUI
import CoreData

struct EditTemplateView: View {
    @StateObject var viewModel: TemplateViewModel
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.presentationMode) var presentationMode
    @State private var conflicts: [String] = []
    @State private var fetchedProps: [String: Any] = [:]
    @State private var forceRefresh: Bool = false
    @State private var draggedItem: EditableTemplateFieldViewData?
    @State private var draggedOffset: CGFloat = 0
    
    var accessToken: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.textPrimary)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 24, height: 24)
                
                Text("Edit Template")
                    .font(.custom("Onest-Medium", size: 20))
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Color.white)
            
            Divider()
                .overlay(Color.divider)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Template Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Template Name")
                            .font(.custom("Onest-Medium", size: 14))
                            .foregroundColor(.textSecondary)
                        
                        TextField("Enter template name", text: $viewModel.templateName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.custom("Onest-Regular", size: 16))
                            .foregroundColor(.textPrimary)
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.cardStroke, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Template Fields
                    ForEach(viewModel.templateFields) { field in
                        EditFieldRow(field: field, json: fetchedProps)
                            .opacity(draggedItem?.id == field.id ? 0.5 : 1.0)
                            .offset(y: draggedItem?.id == field.id ? draggedOffset : 0)
                            .zIndex(draggedItem?.id == field.id ? 1 : 0)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if draggedItem == nil {
                                            draggedItem = field
                                        }
                                        draggedOffset = value.translation.height
                                    }
                                    .onEnded { value in
                                        if let draggedItem = draggedItem,
                                           let fromIndex = viewModel.templateFields.firstIndex(where: { $0.id == draggedItem.id }),
                                           let toIndex = getDestinationIndex(for: value.predictedEndTranslation.height, fromIndex: fromIndex) {
                                            viewModel.templateFields.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex)
                                        }
                                        withAnimation {
                                            self.draggedItem = nil
                                            draggedOffset = 0
                                        }
                                    }
                            )
                    }
                }
                .padding(.bottom, 16)
            }
            
            // Conflicts warning
            if !conflicts.isEmpty {
                Text("Conflicts detected. Reset template?")
                    .font(.custom("Onest-Medium", size: 14))
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                
                Button(action: resetTemplateToNotion) {
                    Text("Reset Template")
                        .font(.custom("Onest-Medium", size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(6)
                }
                .padding(.horizontal, 16)
            }
            
            // Update Template Button
            Button(action: updateTemplate) {
                Text("Update Template")
                    .font(.custom("Onest-Medium", size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canSave() ? Color.accentColor : Color.gray)
                    .cornerRadius(6)
            }
            .padding(16)
            .disabled(!canSave())
        }
        .frame(width: 352, height: 480)
        .background(Color.white)
        .onAppear {
            fetchDatabase(gottaCheck: true)
        }
    }
    
    private func getDestinationIndex(for offsetY: CGFloat, fromIndex: Int) -> Int? {
        let rowHeight: CGFloat = 100 // Approximate height of a FieldRow
        let moveThreshold: CGFloat = rowHeight / 2
        let predictedIndex = fromIndex + Int(offsetY / rowHeight)
        
        if abs(offsetY).truncatingRemainder(dividingBy: rowHeight) > moveThreshold {
            return offsetY > 0 ? min(predictedIndex + 1, viewModel.templateFields.count - 1) : max(predictedIndex - 1, 0)
        } else {
            return min(max(predictedIndex, 0), viewModel.templateFields.count - 1)
        }
    }
    
    func canSave() -> Bool {
        return !viewModel.templateName.isEmpty && allMandatoryFieldsHaveDefaultValue()
    }
    
    func allMandatoryFieldsHaveDefaultValue() -> Bool {
        for field in viewModel.templateFields {
            if field.priority == "mandatory" && field.defaultValue.isEmpty {
                return false
            }
        }
        return true
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
            newField.order = Int16(index)
            newField.kind = fieldViewData.kind
            newField.priority = fieldViewData.priority
            
            if fieldViewData.kind == "multi_select" {
                if let jsonData = try? JSONEncoder().encode(fieldViewData.selectedValues) {
                    newField.defaultValue = String(data: jsonData, encoding: .utf8) ?? ""
                }
            } else {
                newField.defaultValue = fieldViewData.defaultValue
            }
            
            if fieldViewData.kind == "relation" {
                newField.options = nil
            } else if let options = fieldViewData.options {
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: options, requiringSecureCoding: false) as NSData
                    newField.options = data
                } catch {
                    print("Failed to archive options: \(error)")
                }
            }
            
            viewModel.template.addToFields(newField)
        }
        
        do {
            try managedObjectContext.save()
            self.presentationMode.wrappedValue.dismiss()
        } catch {
            print("Failed to update template: \(error)")
        }
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
                        if gottaCheck {
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
    
    func compareFetchedDatabaseWithTemplate(fetchedData: [String: Any], withFields fields: [EditableTemplateFieldViewData]) {
        // Clear the conflicts
        conflicts.removeAll()
        
        // Loop through fetched data and compare with template
        for (key, fetchedValue) in fetchedData {
            if let templateField = viewModel.templateFields.first(where: { $0.name == key }) {
                if let fetchedDict = fetchedValue as? [String: Any] {
                    if templateField.kind != (fetchedDict["type"] as? String) {
                        conflicts.append("Kind mismatch for \(key). Template: \(templateField.kind), Fetched: \(String(describing: fetchedDict["type"]))")
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
    
    func fetchOptions(fetchedData: [String: Any]) {
        for (key, fetchedValue) in fetchedData {
            if let templateField = viewModel.templateFields.first(where: { $0.name == key }) {
                if let fetchedDict = fetchedValue as? [String: Any] {
                    // Handle select fields
                    if templateField.kind == "select", let selectDict = fetchedDict["select"] as? [String: Any],
                       let options = selectDict["options"] as? [[String: Any]] {
                        let optionNames = options.compactMap { $0["name"] as? String }
                        DispatchQueue.main.async {
                            templateField.options = optionNames
                            templateField.defaultValue = optionNames.first ?? ""
                        }
                    }
                    
                    // Handle multi_select fields
                    if templateField.kind == "multi_select", let multiSelectDict = fetchedDict["multi_select"] as? [String: Any],
                       let options = multiSelectDict["options"] as? [[String: Any]] {
                        let optionNames = options.compactMap { $0["name"] as? String }
                        DispatchQueue.main.async {
                            templateField.options = optionNames
                        }
                    }
                    
                    // Handle status fields
                    if templateField.kind == "status", let statusDict = fetchedDict["status"] as? [String: Any],
                       let options = statusDict["options"] as? [[String: Any]] {
                        let optionNames = options.compactMap { $0["name"] as? String }
                        DispatchQueue.main.async {
                            templateField.options = optionNames
                            templateField.defaultValue = optionNames.first ?? ""
                        }
                    }
                    
                    // Handle relation fields
                    if templateField.kind == "relation", let relationDict = fetchedDict["relation"] as? [String: Any],
                        let databaseId = relationDict["database_id"] as? String {
                            fetchRelatedDatabaseTitles(for: databaseId) { titles in
                                DispatchQueue.main.async {
                                    templateField.options = Array(titles.values)
                                    templateField.defaultValue = titles.values.first ?? ""
                                }
                        }
                    }
                }
            }
        }
    }
    
    func fetchRelatedDatabaseTitles(for databaseId: String, completion: @escaping ([String: String]) -> Void) {
        guard let url = URL(string: "https://api.notion.com/v1/databases/\(databaseId)/query") else {
            completion([:])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("2021-08-16", forHTTPHeaderField: "Notion-Version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching related database titles: \(error)")
                completion([:])
                return
            }
            
            guard let data = data else {
                completion([:])
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let results = json["results"] as? [[String: Any]] {
                    var titles: [String: String] = [:]
                    for result in results {
                        if let id = result["id"] as? String,
                           let properties = result["properties"] as? [String: Any],
                           let titleProperty = properties.first(where: { $0.value is [String: Any] && ($0.value as? [String: Any])?["title"] is [[String: Any]] }),
                           let titleArray = (titleProperty.value as? [String: Any])?["title"] as? [[String: Any]],
                           let firstTitle = titleArray.first,
                           let plainText = firstTitle["plain_text"] as? String {
                            titles[id] = plainText
                        }
                    }
                    completion(titles)
                } else {
                    completion([:])
                }
            } catch {
                print("Error parsing related database titles: \(error)")
                completion([:])
            }
        }.resume()
    }
}

    struct EditFieldRow: View {
        @ObservedObject var field: EditableTemplateFieldViewData
        @State var json: [String: Any]
        @State private var showMultiSelect = false

        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "line.horizontal.3")
                    .foregroundColor(.gray)
                    .frame(width: 20, height: 20)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(field.name)
                            .font(.custom("Onest-Medium", size: 16))
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text(field.kind.capitalized)
                            .font(.custom("Onest-Medium", size: 12))
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.cardStroke, lineWidth: 1)
                            )
                    }
                    
                    CustomSegmentedPicker(
                        options: FieldPriority.allCases.map { $0.rawValue.capitalized },
                        selection: Binding(
                            get: { field.priority.capitalized },
                            set: { newValue in
                                field.priority = newValue.lowercased()
                            }
                        )
                    )
                    
                    defaultValueView
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
        
        @ViewBuilder
        var defaultValueView: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Value")
                    .font(.custom("Onest-Medium", size: 14))
                    .foregroundColor(.textSecondary)
                
                switch field.kind {
                case "checkbox":
                    Toggle(isOn: Binding(
                        get: { Bool(field.defaultValue) ?? false },
                        set: { field.defaultValue = String($0) }
                    )) {
                        Text("Default Value")
                    }
                    .disabled(field.priority == "skip")
                case "date":
                    CustomDatePicker(
                        selection: Binding(
                            get: { ISO8601DateFormatter().date(from: field.defaultValue) ?? Date() },
                            set: { field.defaultValue = ISO8601DateFormatter().string(from: $0) }
                        ),
                        disabled: field.priority == "skip"
                    )
                case "select", "status":
                    CustomDropdown(selection: $field.defaultValue, options: field.options?.reduce(into: [String: String]()) { $0[$1] = $1 } ?? [:])
                        .disabled(field.priority == "skip")
                case "multi_select":
                    MultiSelectView(options: field.options ?? [], selectedOptions: Binding(
                        get: { Set(field.selectedValues) },
                        set: { newValues in
                            field.selectedValues = newValues
                            field.defaultValue = Array(newValues).joined(separator: ", ")
                        }
                    )) .frame(width: .infinity)
                    .disabled(field.priority == "skip")
                case "relation":
                    CustomDropdown(selection: $field.defaultValue, options: field.options?.reduce(into: [String: String]()) { $0[$1] = $1 } ?? [:])
                        .disabled(field.priority == "skip")
                default:
                    TextField("Default Value", text: $field.defaultValue)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.cardStroke, lineWidth: 1)
                        )
                        .foregroundColor(.textPrimary)
                        .font(.custom("Onest-Regular", size: 16))
                        .disabled(field.priority == "skip")
                }
            }
            .padding(.vertical, 8)
        }
    }
