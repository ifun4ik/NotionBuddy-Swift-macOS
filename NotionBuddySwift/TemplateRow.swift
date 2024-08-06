import SwiftUI

struct TemplateRow: View {
    let template: Template
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading) {
                Text(template.name ?? "Unnamed Template")
                    .font(.body)
                Text(template.databaseId ?? "No Database")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("⌘+\(template.order)")
                .font(.caption)
                .padding(4)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(4)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}
