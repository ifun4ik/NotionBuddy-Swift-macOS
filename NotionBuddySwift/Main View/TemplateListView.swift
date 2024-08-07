import SwiftUI

struct TemplateListView: View {
    @ObservedObject var viewModel: MainViewModel
    let addNewTemplate: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            TemplateListHeaderView(count: viewModel.templates.count, addNewTemplate: addNewTemplate)
            
            Divider()
                .overlay(Color.divider)
            
            ForEach(Array(viewModel.templates.enumerated()), id: \.element.id) { index, template in
                TemplateRowView(template: template, index: index) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.deleteTemplate(template)
                    }
                }
                if index < viewModel.templates.count - 1 {
                    Divider()
                }
            }
            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .scale.combined(with: .opacity)))
            
            // Add this Spacer to create bottom padding
//            Spacer().frame(height: 12)
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.templates)
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
        .padding(.top, 16)
        .padding(.bottom, 12)
        .padding(.horizontal, 16)
    }
}

import SwiftUI
import AppKit

struct TemplateRowView: View {
    let template: Template
    let index: Int
    @State private var isHovered = false
    @State private var icon: DatabaseIcon?
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Color.iconBackground
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Group {
                    if let icon = icon {
                        switch icon {
                        case .emoji(let emoji):
                            Text(emoji)
                                .font(.system(size: 16))
                        case .url(let urlString):
                            AsyncImage(url: URL(string: urlString)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                case .failure(_):
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        case .custom(let imageData):
                            if let nsImage = NSImage(data: imageData) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                            }
                        }
                    } else {
                        Text("📄")
                            .font(.system(size: 16))
                    }
                }
                .frame(width: 24, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name ?? "Unnamed Template")
                    .font(.custom("Onest-Medium", size: 16))
                    .foregroundColor(.textPrimary)
                Text(template.databaseName ?? "Unknown Database")
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.rowHover : Color.clear)
                .animation(.none, value: isHovered)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .onAppear {
            if let databaseId = template.databaseId {
                icon = DatabaseIconManager.shared.getIcon(for: databaseId)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}
