import SwiftUI
import AppKit

struct QuickCaptureShortcutView: View {
    var body: some View {
        VStack(spacing: 8) {
            if let nsImage = NSImage(named: "keyboard_shortcut") {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 130)
            } else {
                Text("Image not found")
                    .frame(height: 80)
            }
            
            Text("Now, try calling the quick capture")
                .font(.custom("Onest-Medium", size: 18))
                .foregroundColor(.textPrimary)
            
            Text("Press Cmd+Ctrl+N to call the\nquick capture window")
                .font(.custom("Onest-Medium", size: 14))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}
