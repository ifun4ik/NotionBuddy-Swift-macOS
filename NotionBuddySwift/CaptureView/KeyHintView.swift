import SwiftUI

struct KeyHint: Identifiable {
    let id = UUID()
    let key: String
    let action: String
}

struct KeyHintView: View {
    let hints: [KeyHint]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(hints) { hint in
                    HStack(spacing: 4) {
                        Text(hint.key)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        
                        Text(hint.action)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(8)
    }
}
