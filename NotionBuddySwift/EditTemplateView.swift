import SwiftUI
import SDWebImageSwiftUI
import SDWebImageSVGCoder
import CoreData

struct EditTemplateView: View {
    @StateObject var viewModel: TemplateViewModel
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

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
                ForEach(viewModel.templateFields) { field in
                    FieldRow(field: field)
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
            .help(viewModel.templateName.isEmpty ? "Template name is required" : "")
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            viewModel.loadTemplateData()
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
            newField.kind = fieldViewData.kind.rawValue

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
            if field.kind == .mandatory && field.defaultValue.isEmpty {
                return false
            }
        }
        return true
    }
}

extension TemplateFieldViewData: CustomStringConvertible {
    var description: String {
        return "TemplateFieldViewData(name: \(name), fieldType: \(fieldType), defaultValue: \(defaultValue), order: \(order))"
    }
}
