import SwiftUI

struct TemplateListView: View {
    @ObservedObject var viewModel: MainViewModel
    let addNewTemplate: () -> Void
    @State private var selectedTemplate: Template?
    @State private var showEditTemplate = false
    
    var body: some View {
        VStack(spacing: 0) {
            TemplateListHeaderView(count: viewModel.templates.count, addNewTemplate: addNewTemplate)
            
            Divider()
                .overlay(Color.divider)
            
            ForEach(Array(viewModel.templates.enumerated()), id: \.element.id) { index, template in
                TemplateRowView(
                    template: template,
                    index: index,
                    enableHover: true,
                    enableEdit: true,
                    enableDelete: true,
                    onEdit: {
                        selectedTemplate = template
                        showEditTemplate = true
                    },
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.deleteTemplate(template)
                        }
                    }
                )
                if index < viewModel.templates.count - 1 {
                    Divider()
                }
            }
            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .scale.combined(with: .opacity)))
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
        .sheet(item: $selectedTemplate) { template in
            EditTemplateView(viewModel: TemplateViewModel(template: template), accessToken: viewModel.sessionManager.currentAccount?.accessToken ?? "")
                .environment(\.managedObjectContext, viewModel.managedObjectContext)
        }
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
    let enableHover: Bool
    let enableEdit: Bool
    let enableDelete: Bool
    @State private var isHovered = false
    @State private var icon: DatabaseIcon?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    
    @State private var selectedTemplate: Template?
    @State private var showEditTemplate = false

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
            HStack(spacing: 8) {
                if enableEdit {
                    Button(action: {
                        DispatchQueue.main.async {
                            selectedTemplate = template
                            showEditTemplate = true
                            onEdit?()
                        }
                    }) {
                        Image(systemName: "pencil.line")
                            .foregroundColor(.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 24, height: 24)
                }
                
                if enableDelete {
                    Button(action: {
                        onDelete?()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 24, height: 24)
                }
            }
            
            
//            Text("⌘\(index + 1)")
//                .font(.custom("Onest-Medium", size: 14))
//                .foregroundColor(.textSecondary)
//                .padding(.horizontal, 8)
//                .padding(.vertical, 4)
//                .background(Color.shortcutBackground)
//                .cornerRadius(4)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = enableHover ? hovering : false
        }
        .onAppear {
            if let databaseId = template.databaseId {
                icon = DatabaseIconManager.shared.getIcon(for: databaseId)
            }
        }
    }
    
    private var backgroundColor: Color {
        if enableHover && isHovered {
            return Color.rowHover.opacity(0.5)
        } else {
            return Color.clear
        }
    }
}
