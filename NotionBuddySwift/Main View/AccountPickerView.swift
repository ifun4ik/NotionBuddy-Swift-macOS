import SwiftUI

struct AccountPickerView: View {
    let account: NotionAccount
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: account.avatarUrl ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.custom("Onest-Medium", size: 18))
                    .foregroundColor(.textPrimary)
                Text(account.email)
                    .font(.custom("Onest-Regular", size: 14))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.down")
                .font(.system(size: 16, weight: .bold, design: .default))
                .foregroundColor(.iconSecondary)
        }
        .padding(8)
        .padding(.trailing, 12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview
struct AccountPickerView_Previews: PreviewProvider {
    static var previews: some View {
        AccountPickerView(account: NotionAccount(
            id: "1",
            notionBuddyID: "123",
            accessToken: "token",
            name: "John Doe",
            email: "john@example.com",
            avatarUrl: "https://example.com/avatar.jpg",
            workspaceName: "My Workspace",
            workspaceIcon: nil
        ))
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.appBackground)
    }
}
