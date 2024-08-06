import SwiftUI

struct TemplateListView: View {
    let templates: [Template]
    let addNewTemplate: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            TemplateListHeaderView(count: templates.count, addNewTemplate: addNewTemplate)
            
            Divider()
                .overlay(Color.divider)
            
            ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                TemplateRowView(template: template, index: index)
                if index < templates.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

struct TemplateListHeaderView: View {
    let count: Int
    let addNewTemplate: () -> Void
    
    var body: some View {
        HStack {
            Text("Templates")
                .font(.custom("Onest-Medium", size: 20))
                .foregroundColor(.textPrimary)
            
            Text("\(count)")
                .font(.custom("Onest-Medium", size: 14))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.shortcutBackground)
                .cornerRadius(4)
            
            Spacer()
            
            Button(action: addNewTemplate) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                    gradient: Gradient(colors: [.accentColor, .accentDark]),
                    startPoint: .top,
                    endPoint: .bottom))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
                .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 16)
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
    }
}

