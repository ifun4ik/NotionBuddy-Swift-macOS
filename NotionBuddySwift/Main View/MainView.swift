import SwiftUI

struct MainView: View {
    @ObservedObject private var viewModel: MainViewModel
    
    init(sessionManager: SessionManager) {
        _viewModel = ObservedObject(wrappedValue: MainViewModel(sessionManager: sessionManager))
    }
    
    var body: some View {
        if let account = viewModel.currentAccount {
            VStack {
                Text("User Name: \(account.name)")
                
                if let urlString = account.avatarUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .frame(width: 100, height: 100)
                    } placeholder: {
                        ProgressView()
                    }
                } else {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .frame(width: 100, height: 100)
                }
                
                Picker(selection: $viewModel.selectedAccountIndex, label: Text("Select Account")) {
                    ForEach(Array(viewModel.accounts.enumerated()), id: \.element.id) { index, account in
                        Text(account.name).tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 200)
                
                Button(action: {
                    viewModel.addNewAccount()
                }) {
                    Text("Add New Account")
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Spacer()
                }
            }
        } else {
            VStack {
                Text("Please add an account.")
                Button(action: {
                    viewModel.addNewAccount()
                }) {
                    Text("Add New Account")
                }
            }
        }
    }
}
