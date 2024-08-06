import SwiftUI

struct TemplateListView: View {
    let templates: [Template]
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                TemplateRowView(template: template, index: index)
            }
        }
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct TemplateRowView: View {
    let template: Template
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Color.iconBackground
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(template.name?.prefix(1).uppercased() ?? "T")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name ?? "Unnamed Template")
                    .font(.custom("Onest-Medium", size: 16))
                    .foregroundColor(.textPrimary)
                Text(template.databaseId ?? "Unknown Database")
                    .font(.custom("Onest-Regular", size: 12))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("⌘\(index + 1)")
                .font(.custom("Onest-Medium", size: 14))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.shortcutBackground)
                .cornerRadius(4)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.cardBackground)
        .cornerRadius(8)
    }
}
