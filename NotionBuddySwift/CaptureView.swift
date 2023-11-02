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
    
    private var filteredTemplates: [Template] {
        return templates.filter {
            capturedText.isEmpty || $0.name?.lowercased().contains(capturedText.lowercased()) == true
        }
    }
    
    private var displayTemplates: [Template] {
        return Array(filteredTemplates.prefix(5))
    }
    
    private var textFieldText: String {
        if let committedTemplate = committedTemplate {
            return committedTemplate.name ?? ""
        } else {
            return capturedText
        }
    }
    
    private var minHeight: CGFloat {
        if let committedTemplate = committedTemplate {
            return max(CGFloat(TemplateViewModel(template: committedTemplate).templateFields.count) * 48 + 8 * 4, 48 + 8 * 4)
        } else {
            return filteredTemplates.isEmpty ? 48 + 8 * 4 : CGFloat(displayTemplates.count) * 48 + 8 * 4
        }
    }
    
    private var maxHeight: CGFloat {
        if let committedTemplate = committedTemplate {
            return max(CGFloat(TemplateViewModel(template: committedTemplate).templateFields.count) * 48 + 8 * 4, 48 + 8 * 4)
        } else {
            return filteredTemplates.isEmpty ? 48 + 8 * 4 : CGFloat(displayTemplates.count) * 48 + 8 * 4
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
                    ForEach(TemplateViewModel(template: committedTemplate).templateFields, id: \.id) { field in
                        Text(field.name)
                            .font(Font.custom("Onest", size: 16).weight(.semibold))
                            .foregroundColor(Constants.textPrimary)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48, alignment: .leading)
                    }
                } else if displayTemplates.isEmpty {
                    Text("Nothing found")
                        .font(Font.custom("Manrope", size: 16).weight(.semibold))
                        .foregroundColor(Constants.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48, alignment: .leading)
                } else {
                    ForEach(Array(displayTemplates.enumerated()), id: \.element) { index, template in
                        HStack {
                            Text(template.name ?? "No template name")
                                .font(Font.custom("Onest", size: 16).weight(.semibold))
                                .foregroundColor(Constants.textPrimary)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48, alignment: .leading)
                        .background(index == selectedIndex ? Color.blue.opacity(0.2) : Color.clear)
                        .onTapGesture {
                            selectedIndex = index
                        }
                    }
                }
            }
            .frame(minHeight: minHeight, maxHeight: maxHeight)
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
}
