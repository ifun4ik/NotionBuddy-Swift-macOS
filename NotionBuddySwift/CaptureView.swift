import SwiftUI
import SwiftUIIntrospect
import Combine

struct CaptureView: View {
    @FetchRequest(entity: Template.entity(), sortDescriptors: [])
    var templates: FetchedResults<Template>
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    @State private var capturedText: String = ""
    @State private var selectedIndex: Int? = nil  // Track the index of the focused template
    @State private var committedTemplate: Template? = nil  // Track the template that has been committed (selected with Enter)
    @State private var activeFieldIndex: Int? = nil  // Track the index of the active (focused) field
    
    private var filteredTemplates: [Template] {
        return templates.filter {
            capturedText.isEmpty || $0.name?.lowercased().contains(capturedText.lowercased()) == true
        }
    }
    
    private var displayTemplates: [Template] {
        return Array(filteredTemplates.prefix(5))
    }
    
    private var displayFields: [EditableTemplateFieldViewData] {
        guard let committedTemplate = committedTemplate else { return [] }
        return TemplateViewModel(template: committedTemplate).templateFields.filter { $0.priority != "skip" }
    }
    
    private var textFieldText: String {
        if let committedTemplate = committedTemplate {
            return committedTemplate.name ?? ""
        } else {
            return capturedText
        }
    }
    
    var body: some View {
        VStack (spacing: 8) {
            //MARK: Input part
            HStack (alignment: .center, spacing: 12) {
                Image(systemName: "command")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Constants.iconSecondary)
                
                // Display the template name and arrow icon if a template is committed
                if committedTemplate != nil {
                    HStack (spacing: 4) {
                        Text(textFieldText)
                            .font(
                                Font.custom("SF Pro Text", size: 16)
                                    .weight(.medium)
                            )
                            .foregroundColor(Constants.textPrimary)
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Constants.iconSecondary)
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                
                TextField(committedTemplate != nil ? "" : "Type something...", text: $capturedText)
                    .frame(height: 22)
                    .padding(.top, 2)
                    .textFieldStyle(.plain)
                    .font(
                        Font.custom("SF Pro Text", size: 16)
                            .weight(.medium)
                    )
                    .foregroundColor(Constants.textPrimary)
                    .introspect(.textField, on: .macOS(.v10_15, .v11, .v12, .v13, .v14)) { textField in
                        DispatchQueue.main.asyncAfter(deadline: .now()) {
                            textField.becomeFirstResponder()
                            textField.currentEditor()?.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
                        }
                    }
                    .onAppear {
                        setupKeyEventHandling()
                    }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .inset(by: 1)
                    .stroke(Constants.bgPrimaryStroke, lineWidth: 1)
            )
            
            //MARK: Selection
            VStack (spacing: 0){
                if let committedTemplate = committedTemplate {
                    // Display committed template's fields instead of templates
                    ForEach(Array(displayFields.enumerated()), id: \.element.id) { index, field in
                        HStack (spacing: 16){
                            iconForField(field: field, index: index)
                            
                            VStack (alignment: .leading, spacing: 2) {
                                Text(field.name)
                                    .font(Font.custom("Onest", size: 16).weight(.semibold))
                                    .foregroundColor(Constants.textPrimary)
                                
                                Text(field.kind ?? "Unknown")
                                    .font(Font.custom("Onest", size: 14).weight(.medium))
                                    .foregroundColor(Constants.textSecondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
                        .background(index == activeFieldIndex ? Color.blue.opacity(0.2) : Color.clear)
                        .onTapGesture {
                            activeFieldIndex = index
                        }
                    }
                } else if displayTemplates.isEmpty {
                    Text("Nothing found")
                        .font(Font.custom("Manrope", size: 16).weight(.semibold))
                        .foregroundColor(Constants.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
                } else {
                    ForEach(Array(displayTemplates.enumerated()), id: \.element) { index, template in
                        HStack {
                            Text(template.name ?? "No template name")
                                .font(Font.custom("Onest", size: 16).weight(.semibold))
                                .foregroundColor(Constants.textPrimary)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
                        .background(index == selectedIndex ? Color.blue.opacity(0.2) : Color.clear)
                        .onTapGesture {
                            selectedIndex = index
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .inset(by: 1)
                    .stroke(Constants.bgPrimaryStroke, lineWidth: 1)
            )
        }
    }
    
    private func setupKeyEventHandling() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
            return event
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        guard !displayTemplates.isEmpty else { return }
        switch event.keyCode {
        case 125:  // Down arrow key
            if let currentIndex = selectedIndex, currentIndex < displayTemplates.count - 1 {
                selectedIndex = currentIndex + 1
            } else {
                selectedIndex = 0
            }
        case 126:  // Up arrow key
            if let currentIndex = selectedIndex, currentIndex > 0 {
                selectedIndex = currentIndex - 1
            } else {
                selectedIndex = displayTemplates.count - 1
            }
        case 36:  // Enter/Return key
            if let index = selectedIndex, index < displayTemplates.count {
                let selectedTemplate = displayTemplates[index]
                handleCommit(selectedTemplate)
            }
        default:
            break
        }
    }
    
    private func handleCommit(_ selectedTemplate: Template) {
        committedTemplate = selectedTemplate
        capturedText = ""
        selectedIndex = templates.firstIndex(of: selectedTemplate)
        NotificationCenter.default.post(name: NSNotification.Name("CloseCaptureWindow"), object: nil)
    }
    
    private func iconForField(field: EditableTemplateFieldViewData, index: Int) -> some View {
        let iconName: String
        switch field.priority {
        case "optional":
            iconName = "square.dashed"
        case "active" where index == activeFieldIndex:
            iconName = "dot.square"
        case "filled":
            iconName = "checkmark.square"
        default:
            iconName = "square"
        }
        
        return Image(systemName: iconName)
            .resizable()
            .frame(width: 16, height: 16)
            .foregroundColor(Constants.iconSecondary)
    }
}

struct CaptureView_Previews: PreviewProvider {
    static var previews: some View {
        CaptureView()
    }
}

struct Constants {
    static let bgPrimary: Color = .white
    static let bgPrimaryStroke: Color = Color(red: 0.91, green: 0.91, blue: 0.91)
    static let iconSecondary: Color = Color(red: 0.62, green: 0.62, blue: 0.65)
    static let textPrimary: Color = Color(red: 0.27, green: 0.29, blue: 0.38)
    static let textSecondary: Color = Color(red: 0.43, green: 0.42, blue: 0.44)
}
