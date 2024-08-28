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
    var options: [String: String]? = nil
    
    init(
        name: String,
        kind: String,
        defaultValue: String,
        order: Int16,
        options: [String: String]? = nil
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
    var accessToken: String
    
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
                        get: { field.priority.rawValue.capitalized },
                        set: { newValue in
                            if let priority = FieldPriority(rawValue: newValue.lowercased()) {
                                field.priority = priority
                            }
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
                .disabled(field.priority == .skip)
            case "date":
                CustomDatePicker(
                    selection: Binding(
                        get: { ISO8601DateFormatter().date(from: field.defaultValue) ?? Date() },
                        set: { field.defaultValue = ISO8601DateFormatter().string(from: $0) }
                    ),
                    disabled: field.priority == .skip
                )
            case "select", "status":
                CustomDropdown(selection: $field.defaultValue, options: field.options ?? [:])
                    .disabled(field.priority == .skip)
            case "multi_select":
                MultiSelectView(options: field.options?.values.map { $0 } ?? [], selectedOptions: Binding(
                    get: { Set(field.selectedValues) },
                    set: { newValues in
                        field.selectedValues = newValues
                        field.defaultValue = Array(newValues).joined(separator: ", ")
                    }
                )) .frame(width: .infinity)
                .disabled(field.priority == .skip)
            case "relation":
                CustomDropdown(selection: $field.defaultValue, options: field.options ?? [:])
                    .disabled(field.priority == .skip)
                    .onAppear {
                        if let databaseId = field.options?.first?.key {
                            fetchRelatedDatabaseTitles(for: databaseId) { titles in
                                DispatchQueue.main.async {
                                    field.options = titles
                                    field.defaultValue = titles.values.first ?? ""
                                }
                            }
                        }
                    }
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
                    .disabled(field.priority == .skip)
            }
        }
        .padding(.vertical, 8)
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

struct TemplateCreatorView: View {
    var database: Database
    var onSave: () -> Void
    @State private var templateName: String = ""
    @State var templateFields: [TemplateFieldViewData] = []
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false
    @State private var existingNames: [String] = []
    
    @State private var draggedItem: TemplateFieldViewData?
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
                } .buttonStyle(PlainButtonStyle())
                    .frame(width: 24, height: 24)
                
                Text("\(database.name) Template")
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
                        
                        TextField("Enter template name", text: $templateName)
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
                    ForEach(templateFields) { field in
                        FieldRow(field: field, accessToken: accessToken)
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
                                           let fromIndex = templateFields.firstIndex(where: { $0.id == draggedItem.id }),
                                           let toIndex = getDestinationIndex(for: value.predictedEndTranslation.height, fromIndex: fromIndex) {
                                            moveField(from: IndexSet(integer: fromIndex), to: toIndex)
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
            
            // Save Template Button
            Button(action: saveTemplate) {
                Text("Save Template")
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
            existingNames = fetchExistingNames()
            createFieldViewData(from: database)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text("A template with this name already exists."), dismissButton: .default(Text("OK")))
        }
    }

    private func getDestinationIndex(for offsetY: CGFloat, fromIndex: Int) -> Int? {
        let rowHeight: CGFloat = 100 // Approximate height of a FieldRow
        let moveThreshold: CGFloat = rowHeight / 2
        let predictedIndex = fromIndex + Int(offsetY / rowHeight)
        
        if abs(offsetY).truncatingRemainder(dividingBy: rowHeight) > moveThreshold {
            return offsetY > 0 ? min(predictedIndex + 1, templateFields.count - 1) : max(predictedIndex - 1, 0)
        } else {
            return min(max(predictedIndex, 0), templateFields.count - 1)
        }
    }
    
    func moveField(from source: IndexSet, to destination: Int) {
        templateFields.move(fromOffsets: source, toOffset: destination)
        for (index, field) in templateFields.enumerated() {
            field.order = Int16(index)
        }
    }

    func fetchExistingNames() -> [String] {
        let fetchRequest: NSFetchRequest<Template> = Template.fetchRequest()
        do {
            return try viewContext.fetch(fetchRequest).compactMap { $0.name }
        } catch {
            print("Failed to fetch existing names: \(error)")
            return []
        }
    }
    
    func createFieldViewData(from database: Database) {
        if let properties = database.properties {
            var skipPriorityFields: [TemplateFieldViewData] = []

            for (name, property) in properties {
                var options: [String: String] = [:]

                switch property.type {
                case "select":
                    options = property.select?.options.reduce(into: [:]) { result, option in
                        result[option.id] = option.name
                    } ?? [:]
                case "multi_select":
                    options = property.multi_select?.options.reduce(into: [:]) { result, option in
                        result[option.id] = option.name
                    } ?? [:]
                case "status":
                    options = property.status?.options.reduce(into: [:]) { result, option in
                        result[option.id] = option.name
                    } ?? [:]
                case "relation":
                    if let databaseId = property.relation?.database_id {
                        options = [databaseId: "Loading..."]
                    }
                default:
                    break
                }

                let fieldViewData = TemplateFieldViewData(
                    name: name,
                    kind: property.type,
                    defaultValue: "",
                    order: Int16(templateFields.count),
                    options: options.isEmpty ? nil : options
                )

                if fieldViewData.priority == .skip {
                    skipPriorityFields.append(fieldViewData)
                } else {
                    templateFields.append(fieldViewData)
                }
            }

            templateFields.append(contentsOf: skipPriorityFields)
        }
    }
    
    func saveTemplate() {
        if existingNames.contains(templateName) {
            showAlert = true
            return
        }
        
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
            } else if fieldViewData.kind == "relation" {
                newField.defaultValue = fieldViewData.defaultValue
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
        
        do {
            try viewContext.save()
            onSave()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Failed to save template: \(error)")
            showAlert = true
        }
    }
    
    func canSave() -> Bool {
        return !templateName.isEmpty && allMandatoryFieldsHaveDefaultValue()
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
    @State private var isExpanded = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    if selectedOptions.isEmpty {
                        Text("Select options")
                            .font(.custom("Onest-Regular", size: 16))
                            .foregroundColor(.textSecondary)
                    } else {
                        Text(selectedOptions.joined(separator: ", "))
                            .font(.custom("Onest-Regular", size: 16))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.textSecondary)
                        .rotationEffect(Angle(degrees: isExpanded ? 180 : 0))
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(options, id: \.self) { option in
                            Button(action: {
                                toggleOption(option)
                            }) {
                                HStack {
                                    if let firstWord = option.components(separatedBy: .whitespaces).first,
                                       firstWord.unicodeScalars.allSatisfy({ $0.properties.isEmoji }) {
                                        Text(firstWord)
                                            .font(.system(size: 18))
                                        Text(option.trimmingPrefix(firstWord).trimmingCharacters(in: .whitespaces))
                                            .font(.custom("Onest-Regular", size: 16))
                                    } else {
                                        Text(option)
                                            .font(.custom("Onest-Regular", size: 16))
                                    }
                                    Spacer()
                                    if selectedOptions.contains(option) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .foregroundColor(.textPrimary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(selectedOptions.contains(option) ? Color.bgSecondary : Color.clear)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .frame(height: min(CGFloat(options.count) * 44, 200))
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
        .padding()
        .background(Color.white)
    }

    private func toggleOption(_ option: String) {
        if selectedOptions.contains(option) {
            selectedOptions.remove(option)
        } else {
            selectedOptions.insert(option)
        }
    }
}

struct CustomSegmentedPicker: View {
    let options: [String]
    @Binding var selection: String
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.bgSecondary)
                    .frame(height: 32)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .frame(width: segmentWidth(in: geometry))
                    .offset(x: segmentOffset(in: geometry))
                    .frame(height: 28)
                
                HStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        Text(option)
                            .font(.custom("Onest-Medium", size: 14))
                            .foregroundColor(selection == option ? .textPrimary : .textSecondary)
                            .frame(width: segmentWidth(in: geometry))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selection = option
                                }
                            }
                    }
                }
                .padding(2) // Add horizontal padding here
            }
        }
        .frame(height: 32)
    }
    
    private func segmentWidth(in geometry: GeometryProxy) -> CGFloat {
        (geometry.size.width - 4) / CGFloat(options.count) // Subtract 4 for the left and right 2px padding
    }
    
    private func segmentOffset(in geometry: GeometryProxy) -> CGFloat {
        let index = CGFloat(options.firstIndex(of: selection) ?? 0)
        return 2 + index * segmentWidth(in: geometry) // Add 2 for the left padding
    }
}


struct CustomDropdown: View {
    @Binding var selection: String
    let options: [String: String]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(options[selection] ?? selection)
                        .font(.custom("Onest-Regular", size: 16))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.textSecondary)
                        .rotationEffect(Angle(degrees: isExpanded ? 180 : 0))
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(options.keys.sorted()), id: \.self) { key in
                            Button(action: {
                                selection = key
                                withAnimation {
                                    isExpanded = false
                                }
                            }) {
                                HStack {
                                    Text(options[key] ?? "")
                                        .font(.custom("Onest-Regular", size: 16))
                                        .foregroundColor(.textPrimary)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(selection == key ? Color.bgSecondary : Color.clear)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .frame(height: min(CGFloat(options.count) * 44, 200))
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
    }
}

