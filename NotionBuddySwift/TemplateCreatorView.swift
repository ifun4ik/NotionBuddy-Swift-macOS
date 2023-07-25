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

class TemplateFieldViewData: ObservableObject {
    let id = UUID()
    let name: String
    let fieldType: String
    var kind: FieldKind = .mandatory
    @Published var defaultValue: String
    var options: [String]? = nil

    init(name: String, fieldType: String, defaultValue: String, options: [String]? = nil) {
        self.name = name
        self.fieldType = fieldType
        self.defaultValue = defaultValue
        self.options = options
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
                ForEach(templateFields.indices, id: \.self) { index in
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Field Name:")
                                .font(.headline)
                            Text(templateFields[index].name)
                                .font(.body)
                        }
                        HStack {
                            Text("Field Type:")
                                .font(.headline)
                            Text(templateFields[index].fieldType)
                                .font(.body)
                        }
                        
                        switch templateFields[index].fieldType {
                        case "checkbox":
                            Toggle(isOn: Binding(get: {
                                Bool(templateFields[index].defaultValue) ?? false
                            }, set: {
                                templateFields[index].defaultValue = String($0)
                            })) {
                                Text("Default Value")
                            }
                        case "date":
                            DatePicker("", selection: Binding(get: {
                                Date()
                            }, set: {
                                templateFields[index].defaultValue = "\($0)"
                            }))
                                .labelsHidden()
                        case "email", "phone_number", "rich_text", "title", "url":
                            TextField("Default Value", text: $templateFields[index].defaultValue)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        case "multi_select", "select", "status":
                            Picker(selection: $templateFields[index].defaultValue, label: Text("Default Value")) {
                                ForEach(templateFields[index].options ?? [], id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                        default:
                            TextField("Default Value", text: .constant(""))
                                .disabled(true)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                }
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
        }
        
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
//        .cornerRadius(16)
//        .shadow(radius: 10)
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
                    templateFields.append(TemplateFieldViewData(name: name, fieldType: property.type, defaultValue: defaultValue, options: options))
                } else if let statusOptions = property.status?.options {
                    let options = statusOptions.map { $0.name }
                    let defaultValue = options.first ?? ""
                    templateFields.append(TemplateFieldViewData(name: name, fieldType: property.type, defaultValue: defaultValue, options: options))
                } else {
                    let defaultValue = ""
                    templateFields.append(TemplateFieldViewData(name: name, fieldType: property.type, defaultValue: defaultValue))
                }
            }
        }
    }

    func saveTemplate() {
        // Create a new Template entity
        let newTemplate = Template(context: managedObjectContext)
        newTemplate.id = UUID()
        newTemplate.name = templateName
        newTemplate.order = Int16(templateFields.count)
        
        // Create TemplateField entities for each field
        for (index, fieldViewData) in templateFields.enumerated() {
            let newField = TemplateField(context: managedObjectContext)
            newField.id = fieldViewData.id
            newField.name = fieldViewData.name
            newField.defaultValue = fieldViewData.defaultValue
            newField.order = Int16(index)
            newField.kind = fieldViewData.kind.rawValue
            
            // Add the new field to the template
            newTemplate.addToFields(newField)
        }
        
        // Save the context
        do {
            try managedObjectContext.save()
            self.presentationMode.wrappedValue.dismiss()
            self.shouldDismiss = true
        } catch {
            print("Failed to save template: \(error)")
        }
    }
}
