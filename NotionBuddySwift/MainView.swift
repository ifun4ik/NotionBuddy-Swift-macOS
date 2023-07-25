import SwiftUI
import CoreData

struct MainView: View {
    @ObservedObject var sessionManager: SessionManager
    
    var body: some View {
        if sessionManager.accounts.isEmpty || sessionManager.selectedAccountIndex < 0 || sessionManager.selectedAccountIndex >= sessionManager.accounts.count {
            VStack {
                Text("Please add an account.")
                Button(action: {
                    self.sessionManager.startWebAuthSession()
                }) {
                    Text("Add New Account")
                }
            }
        } else {
            VStack {
                // User's name
                Text("User Name: \(sessionManager.accounts[sessionManager.selectedAccountIndex].name)")
                
                // User's photo
                if let urlString = sessionManager.accounts[sessionManager.selectedAccountIndex].avatarUrl, let url = URL(string: urlString) {
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
                
                // Account selector
                Picker(selection: $sessionManager.selectedAccountIndex, label: Text("Select Account")) {
                    ForEach(sessionManager.accounts.indices, id: \.self) { index in
                        Text(sessionManager.accounts[index].name).tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 200)
                
                // Add new account button
                Button(action: {
                    self.sessionManager.startWebAuthSession()
                }) {
                    Text("Add New Account")
                }
            }
            .toolbar{
                Spacer()
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(sessionManager: SessionManager())
    }
}
