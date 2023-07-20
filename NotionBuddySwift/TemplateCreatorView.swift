import SwiftUI

enum FieldKind: String, CaseIterable, Identifiable {
    case mandatory
    case optional
    case skip
    
    var id: String { self.rawValue }
}

struct TemplateFieldViewData: Identifiable {
    var id = UUID()
    var name: String
    var fieldType: String
    var kind: FieldKind = .mandatory
    var defaultValue: Any? = nil
}

struct TemplateCreatorView: View {
    var database: Database
    @State private var templateName: String = ""
    @State private var templateFields: [TemplateFieldViewData] = []
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Template Name:")
                    .font(.headline)
                TextField("Enter a name", text: $templateName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 20)
            
            Divider()
            
            List {
                ForEach(templateFields) { field in
                    VStack(alignment: .leading) {
                        Text("Field Name:")
                            .font(.headline)
                        Text(field.name)
                            .font(.body)
                        
                        Text("Field Type:")
                            .font(.headline)
                        Text(field.fieldType)
                            .font(.body)
                        
                        switch field.kind {
                        case .mandatory:
                            TextField("Default Value", text: Binding(
                                get: { field.defaultValue as? String ?? "" },
                                set: { _ = $0 } // No assignment needed
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        case .optional:
                            Toggle("Is Optional", isOn: Binding(
                                get: { field.defaultValue as? Bool ?? false },
                                set: { _ = $0 } // No assignment needed
                            ))
                        
                        case .skip:
                            Text("Skip field")
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
//                    .background(Color.secondary.opacity(0.2))
//                    .cornerRadius(8)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
//            .padding(.horizontal, -20)
            
            Spacer()
            
            Button(action: saveTemplate) {
                Text("Save Template")
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 40)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 20)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(16)
        .shadow(radius: 10)
        .onAppear {
            createFieldViewData(from: database)
        }
    }
    
    func createFieldViewData(from database: Database) {
        if let properties = database.properties {
            for (name, property) in properties {
                templateFields.append(TemplateFieldViewData(name: name, fieldType: property.type))
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
            newField.defaultValue = fieldViewData.defaultValue as? String
            newField.order = Int16(index)
            newField.kind = fieldViewData.kind.rawValue
            
            // Add the new field to the template
            newTemplate.addToFields(newField)
        }
        
        // Save the context
        do {
            try managedObjectContext.save()
        } catch {
            print("Failed to save template: \(error)")
        }
    }
}
