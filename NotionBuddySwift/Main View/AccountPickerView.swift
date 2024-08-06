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
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.custom("Onest-Medium", size: 16))
                    .foregroundColor(.textPrimary)
                Text(account.email)
                    .font(.custom("Onest-Regular", size: 14))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.down")
                .foregroundColor(.textSecondary)
        }
        .padding(16)
    }
}
