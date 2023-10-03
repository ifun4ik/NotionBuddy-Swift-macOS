import SwiftUI

struct CaptureView: View {
    @State private var capturedText: String = ""
    
    var body: some View {
        TextField("Type something...", text: $capturedText, onCommit: {
            handleCommit()
        })
        .textFieldStyle(.plain)
        .padding(16)
        .background(Color(#colorLiteral(red: 0.035, green: 0.063, blue: 0.101, alpha: 1)))
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color(#colorLiteral(red: 0.8901960784, green: 0.937254902, blue: 0.968627451, alpha: 0.1)), lineWidth: 1)
        )
    }
    
    private func handleCommit() {
        print("Captured Text: \(capturedText)")
        NotificationCenter.default.post(name: NSNotification.Name("CloseCaptureWindow"), object: nil)
    }
}
