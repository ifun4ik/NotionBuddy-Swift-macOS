import SwiftUI
import SwiftUIIntrospect
import Combine

struct CaptureView: View {
    @FetchRequest(entity: Template.entity(), sortDescriptors: [])
    var templates: FetchedResults<Template>
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    @State private var capturedText: String = ""
    @State private var selectedIndex: Int? = nil
    @State private var committedTemplate: Template? = nil
    @State private var activeFieldIndex: Int? = nil
    @State private var filledFields: Set<Int> = []
    @State private var isPlaceholderActive: Bool = true
    @State private var capturedData: [String: String] = [:]
    
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
    
    private var textFieldPlaceholder: String {
        if isPlaceholderActive, let index = activeFieldIndex, index < displayFields.count {
            return displayFields[index].defaultValue ?? ""
        }
        return "Type something..."
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "command")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Constants.iconSecondary)
                
                if let committedTemplate = committedTemplate {
                    HStack(spacing: 4) {
                        Text(committedTemplate.name ?? "")
                            .font(Font.custom("SF Pro Text", size: 16).weight(.medium))
                            .foregroundColor(Constants.textPrimary)
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Constants.iconSecondary)
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                
                TextField(textFieldPlaceholder, text: $capturedText)
                    .frame(height: 22)
                    .padding(.top, 2)
                    .textFieldStyle(.plain)
                    .font(Font.custom("SF Pro Text", size: 16).weight(.medium))
                    .foregroundColor(Constants.textPrimary)
                    .introspect(.textField, on: .macOS(.v10_15, .v11, .v12, .v13, .v14)) { textField in
                        DispatchQueue.main.asyncAfter(deadline: .now()) {
                            textField.becomeFirstResponder()
                            textField.currentEditor()?.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
                            
                            if committedTemplate != nil, let index = activeFieldIndex, index < displayFields.count {
                                isPlaceholderActive = displayFields[index].defaultValue != nil
                            } else if committedTemplate != nil {
                                activeFieldIndex = 0
                                isPlaceholderActive = displayFields.first?.defaultValue != nil
                            }
                            
                            if let placeholderString = textField.placeholderString {
                                let placeholderFont = NSFont(name: "SF Pro Text", size: 16) ?? NSFont.systemFont(ofSize: 16)
                                let placeholderAttributes: [NSAttributedString.Key: Any] = [
                                    .foregroundColor: NSColor(Constants.textSecondary),
                                    .font: placeholderFont
                                ]
                                textField.placeholderAttributedString = NSAttributedString(string: placeholderString, attributes: placeholderAttributes)
                            }
                        }
                    }
                    .onChange(of: capturedText) { newValue in
                        if activeFieldIndex == 0 && !filledFields.contains(0) {
                            if newValue != textFieldPlaceholder && isPlaceholderActive {
                                capturedText = newValue
                                isPlaceholderActive = false
                            }
                        }
                    }
                    .onAppear {
                        capturedData = [:]
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
            
            VStack(spacing: 0) {
                if let committedTemplate = committedTemplate {
                    ForEach(Array(displayFields.enumerated()), id: \.element.id) { index, field in
                        HStack(spacing: 16) {
                            iconForField(field: field, index: index)
                            
                            VStack(alignment: .leading, spacing: 2) {
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
                        .background(index == activeFieldIndex ? Constants.bgPrimaryHover : Color.clear)
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
                        .background(index == selectedIndex ? Constants.bgPrimaryHover : Color.clear)
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
            self.handleKeyEvent(event)
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.keyCode == 36 {
            cmdEnterPressed()
            return
        }

        if let committedTemplate = committedTemplate, let activeFieldIndex = activeFieldIndex {
            switch event.keyCode {
            case 36:  // Enter/Return key
                print("Hey from 182")
                captureCurrentFieldData()
                moveToNextFieldOrFinish()
            default:
                break
            }
        } else {
            handleTemplateSelection(event: event)
        }
    }

    private func captureCurrentFieldData() {
        guard let activeFieldIndex = activeFieldIndex, activeFieldIndex < displayFields.count else { return }
        let field = displayFields[activeFieldIndex]
        capturedData[field.name] = capturedText.isEmpty ? (field.defaultValue ?? "") : capturedText
        filledFields.insert(activeFieldIndex)
    }

    private func moveToNextFieldOrFinish() {
        if activeFieldIndex == displayFields.count - 1 {
            print("Move Next Called")
            finishCapture()
        } else {
            activeFieldIndex! += 1
            capturedText = ""
        }
    }

    private func handleTemplateSelection(event: NSEvent) {
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
            if let index = selectedIndex {
                commitTemplate(displayTemplates[index])
                print("Hey from 227")
            }
        default:
            break
        }
    }

    private func cmdEnterPressed() {
        captureAllFieldData()
        if validateRequiredFields() {
            print("Cmd+Enter Called")
            finishCapture()
            captureCurrentFieldData()
            closeCaptureView()  // Implement this method to close the capture view
        } else {
            highlightUnfilledRequiredFields()
        }
    }

    private func captureAllFieldData() {
        for (index, field) in displayFields.enumerated() {
            let fieldValue = index == activeFieldIndex ? capturedText : (capturedData[field.name] ?? field.defaultValue ?? "")
            capturedData[field.name] = fieldValue
            filledFields.insert(index)
        }
    }

    private func validateRequiredFields() -> Bool {
        for field in displayFields where field.priority == "required" {
            if (capturedData[field.name] ?? "").isEmpty {
                return false
            }
        }
        return true
    }

    private func highlightUnfilledRequiredFields() {
        for (index, field) in displayFields.enumerated() {
            if field.priority == "required" && (capturedData[field.name] ?? "").isEmpty {
                filledFields.remove(index)
            }
        }
    }

    private func finishCapture() {
        print("Capture Finished - Captured Data: \(capturedData)")
        capturedData = [:]
        committedTemplate = nil
        capturedText = ""
        print("Captured Data: \(capturedData)")
        // Additional logic to handle captured data
    }

    private func closeCaptureView() {
        // Logic to close the capture view
    }

    private func commitTemplate(_ template: Template) {
        committedTemplate = template
        activeFieldIndex = 0
        capturedText = ""
        selectedIndex = nil
        filledFields = []
        capturedData = [:]  // Reset captured data for the new template
    }

    private func handleCommit(_ selectedTemplate: Template) {
        committedTemplate = selectedTemplate
        capturedText = ""
        selectedIndex = templates.firstIndex(of: selectedTemplate)
        NotificationCenter.default.post(name: NSNotification.Name("CloseCaptureWindow"), object: nil)
    }

    private func iconForField(field: EditableTemplateFieldViewData, index: Int) -> some View {
        let iconName: String
        let isFieldFilled = filledFields.contains(index)
        let isFieldRequiredAndEmpty = field.priority == "required" && (capturedData[field.name] ?? "").isEmpty

        if isFieldFilled && !isFieldRequiredAndEmpty {
            iconName = "checkmark.square"
        } else if isFieldRequiredAndEmpty {
            iconName = "exclamationmark.triangle"
        } else {
            iconName = "square"
        }

        return Image(systemName: iconName)
            .resizable()
            .frame(width: 16, height: 16)
            .foregroundColor(isFieldRequiredAndEmpty ? Color.red : Constants.iconSecondary)
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
        static let bgPrimaryHover: Color = Color(red: 0.95, green: 0.95, blue: 0.95)
    }
