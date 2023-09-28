import SwiftUI

struct CaptureView: View {
    @State private var capturedText: String = ""
    
    var body: some View {
        TextField("Type something...", text: $capturedText, onCommit: {
            handleCommit()
        })
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .padding()
    }
    
    private func handleCommit() {
        print("Captured Text: \(capturedText)")
        NotificationCenter.default.post(name: NSNotification.Name("CloseCaptureWindow"), object: nil)
    }
}
