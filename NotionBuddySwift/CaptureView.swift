import SwiftUI
import SwiftUIIntrospect

struct CaptureView: View {
    @FetchRequest(entity: Template.entity(), sortDescriptors: [])
    var templates: FetchedResults<Template>
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    @State private var capturedText: String = ""
    
    var body: some View {
        VStack (spacing: 8) {
            //MARK: Input part
            HStack (alignment: .center, spacing: 12) {
                Image(systemName: "command")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(Color(red: 225/255, green: 238/255, blue: 246/255, opacity: 1))
                
                TextField("Type something...", text: $capturedText, onCommit: {
                    handleCommit()
                })
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
                        .font(
                            Font.custom("Manrope", size: 16)
                                .weight(.semibold)
                        )
                        .foregroundColor(Color(red: 0.88, green: 0.93, blue: 0.96))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                ForEach (templates){ template in
                    HStack {
                        Text(template.name ?? "No template name")
                            .font(
                                Font.custom("Manrope", size: 16)
                                    .weight(.semibold)
                            )
                            .foregroundColor(Color(red: 0.88, green: 0.93, blue: 0.96))
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48, alignment: .leading)
                }
            }
            .background(Color(#colorLiteral(red: 0.035, green: 0.063, blue: 0.101, alpha: 1)))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(red: 0.88, green: 0.93, blue: 0.96).opacity(0.1), lineWidth: 1)
            )
            
        }
        
    }
    
    private func handleCommit() {
        print("Captured Text: \(capturedText)")
        NotificationCenter.default.post(name: NSNotification.Name("CloseCaptureWindow"), object: nil)
    }
}

struct CaptureView_Previews : PreviewProvider {
    static var previews : some View {
        CaptureView()
    }
}
