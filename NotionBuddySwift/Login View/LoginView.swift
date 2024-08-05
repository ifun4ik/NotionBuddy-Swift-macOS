import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    
    init(sessionManager: SessionManager) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(sessionManager: sessionManager))
    }

    var body: some View {
        VStack {
            Button(action: {
                viewModel.authenticate()
            }) {
                Text("Authenticate with Notion")
            }

            if viewModel.isAuthenticating {
                ProgressView()
            }
        }
        .onAppear {
            viewModel.checkExistingAuthentication()
        }
        .alert(item: $viewModel.error) { error in
            Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
    }
}
