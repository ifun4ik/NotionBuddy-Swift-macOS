import SwiftUI

struct CaptureView: View {
    @State private var capturedText: String = ""
    
    var body: some View {
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

        }
        .padding(16)
        .background(Color(#colorLiteral(red: 0.035, green: 0.063, blue: 0.101, alpha: 1)))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color(red: 0.88, green: 0.93, blue: 0.96).opacity(0.1), lineWidth: 1)
            
        )
        
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
