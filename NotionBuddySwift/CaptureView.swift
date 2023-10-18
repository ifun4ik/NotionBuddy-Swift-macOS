import SwiftUI
import SwiftUIIntrospect
import Combine

struct CaptureView: View {
    @FetchRequest(entity: Template.entity(), sortDescriptors: [])
    var templates: FetchedResults<Template>
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    @State private var capturedText: String = ""
    @State private var selectedIndex: Int? = nil  // Track the index of the selected template
    
    private var filteredTemplates: [Template] {
        return templates.filter {
            capturedText.isEmpty || $0.name?.lowercased().contains(capturedText.lowercased()) == true
        }
    }
    
    private var minHeight: CGFloat {
        return filteredTemplates.isEmpty ? 48 + 8 * 4 : CGFloat(filteredTemplates.count > 5 ? 5 : filteredTemplates.count) * 48 + 8 * 4
    }
    
    private var maxHeight: CGFloat {
        return filteredTemplates.isEmpty ? 48 + 8 * 4 : CGFloat(filteredTemplates.count > 5 ? 5 : filteredTemplates.count) * 48 + 8 * 4
    }
    
    var body: some View {
        VStack (spacing: 8) {
            //MARK: Input part
            HStack (alignment: .center, spacing: 12) {
                Image(systemName: "command")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(Color(red: 225/255, green: 238/255, blue: 246/255, opacity: 1))
                
                TextField("Type something...", text: $capturedText)
                    .frame(height: 22)
                    .padding(.top, 2)
                    .textFieldStyle(.plain)
                    .font(
                        Font.custom("Manrope", size: 16)
                            .weight(.medium)
                    )
                    .foregroundColor(Color(red: 0.88, green: 0.93, blue: 0.96))
                    .introspect(.textField, on: .macOS(.v10_15, .v11, .v12, .v13, .v14)) { textField in
                        DispatchQueue.main.asyncAfter(deadline: .now()) {
                            textField.becomeFirstResponder()
                            textField.currentEditor()?.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
                        }
                    }
            }
            .padding(16)
            .background(Color(#colorLiteral(red: 0.035, green: 0.063, blue: 0.101, alpha: 1)))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(red: 0.88, green: 0.93, blue: 0.96).opacity(0.1), lineWidth: 1)
            )
            
            //MARK: Selection
            VStack (spacing: 0){
                Group {
                    Text("Pick the template")
                        .font(Font.custom("Manrope", size: 16).weight(.semibold))
                        .foregroundColor(Color(red: 0.88, green: 0.93, blue: 0.96))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                if filteredTemplates.isEmpty {
                    Text("Nothing found")
                        .font(Font.custom("Manrope", size: 16).weight(.semibold))
                        .foregroundColor(Color(red: 0.88, green: 0.93, blue: 0.96))
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48, alignment: .leading)
                } else {
                    ForEach(Array(filteredTemplates.prefix(5).enumerated()), id: \.element) { index, template in
                        HStack {
                            Text(template.name ?? "No template name")
                                .font(Font.custom("Manrope", size: 16).weight(.semibold))
                                .foregroundColor(Color(red: 0.88, green: 0.93, blue: 0.96))
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48, alignment: .leading)
                        .background(index == selectedIndex ? Color.blue.opacity(0.2) : Color.clear)  // Highlight if selected
                        .onTapGesture {
                            selectedIndex = index  // Update selection on tap
                        }
                    }
                }
            }
            .frame(minHeight: minHeight, maxHeight: maxHeight)
            .background(Color(#colorLiteral(red: 0.035, green: 0.063, blue: 0.101, alpha: 1)))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(red: 0.88, green: 0.93, blue: 0.96).opacity(0.1), lineWidth: 1)
            )
            
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKeyEvent(event)
                return event
            }
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
            guard !filteredTemplates.isEmpty else { return }
            switch event.keyCode {
            case 125:  // Down arrow key
                selectedIndex = min((selectedIndex ?? -1) + 1, filteredTemplates.count - 1)
            case 126:  // Up arrow key
                selectedIndex = max((selectedIndex ?? 0) - 1, 0)
            case 36:  // Enter/Return key
                if let index = selectedIndex {
                    let selectedTemplate = filteredTemplates[index]
                    handleCommit(selectedTemplate)
                }
            default:
                break
            }
        }
    
    private func handleCommit(_ selectedTemplate: Template? = nil) {
            if let selectedTemplate = selectedTemplate {
                print("Selected Template: \(selectedTemplate.name ?? "No name")")
            } else {
                print("Captured Text: \(capturedText)")
            }
            NotificationCenter.default.post(name: NSNotification.Name("CloseCaptureWindow"), object: nil)
        }
}


struct CaptureView_Previews: PreviewProvider {
    static var previews: some View {
        CaptureView()
    }
}
