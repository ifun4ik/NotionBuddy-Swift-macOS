import SwiftUI

struct AccountPicker: View {
    @ObservedObject var viewModel: AccountPickerViewModel
    
    var body: some View {
        Menu {
            ForEach(viewModel.accounts) { account in
                Button(action: { viewModel.selectAccount(account) }) {
                    Text(account.name)
                }
            }
            Divider()
            Button("Add Account", action: viewModel.addAccount)
        } label: {
            HStack {
                AsyncImage(url: URL(string: viewModel.currentAccount?.avatarUrl ?? "")) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Image(systemName: "person.crop.circle")
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(viewModel.currentAccount?.name ?? "Select Account")
                        .font(.headline)
                    Text(viewModel.currentAccount?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}
