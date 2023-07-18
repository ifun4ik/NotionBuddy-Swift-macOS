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
        VStack {
            TextField("Template Name", text: $templateName)
            List {
                ForEach(templateFields.indices, id: \.self) { index in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(templateFields[index].name)
                            Text(templateFields[index].fieldType)
                        }
                        Picker("Kind", selection: $templateFields[index].kind) {
                            ForEach(FieldKind.allCases) { kind in
                                Text(kind.rawValue.capitalized).tag(kind)
                            }
                        }
                        TextField("Default Value", text: Binding(
                            get: { templateFields[index].defaultValue as? String ?? "" },
                            set: { templateFields[index].defaultValue = $0 }
                        ))
                    }
                }
            }
            Button("Save Template") {
                saveTemplate()
            }
        }
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
