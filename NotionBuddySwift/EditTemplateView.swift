import SwiftUI
import CoreData

struct EditTemplateView: View {
    var template: Template
    @State private var templateName: String
    @State var templateFields: [TemplateFieldViewData]
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    init(template: Template) {
        self.template = template
        self._templateName = State(initialValue: template.name ?? "")
        
        if let fields = template.fields as? Set<TemplateField> {
            let sortedFields = fields.sorted(by: { $0.order < $1.order })
            self._templateFields = State(initialValue: sortedFields.map {
                TemplateFieldViewData(name: $0.name ?? "", fieldType: $0.kind ?? "", defaultValue: $0.defaultValue ?? "", order: $0.order)
            })
        } else {
            self._templateFields = State(initialValue: [])
        }
    }
    
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
                    Text(field.name)
                }
                .onMove(perform: move)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .cornerRadius(8)
            
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
            .help(templateName.isEmpty ? "Template name is required" : "")
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    func move(from source: IndexSet, to destination: Int) {
        templateFields.move(fromOffsets: source, toOffset: destination)
        for (index, field) in templateFields.enumerated() {
            field.order = Int16(index)
        }
    }
    
    func updateTemplate() {
        template.name = templateName
        if let fields = template.fields as? Set<TemplateField> {
            for field in fields {
                if let updatedFieldViewData = templateFields.first(where: { $0.id == field.id }) {
                    field.defaultValue = updatedFieldViewData.defaultValue
                    field.order = updatedFieldViewData.order
                    field.kind = updatedFieldViewData.kind.rawValue
                }
            }
        }
        
        do {
            try managedObjectContext.save()
            self.presentationMode.wrappedValue.dismiss()
        } catch {
            print("Failed to update template: \(error)")
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
            if field.kind == .mandatory && field.defaultValue.isEmpty {
                return false
            }
        }
        return true
    }
}
