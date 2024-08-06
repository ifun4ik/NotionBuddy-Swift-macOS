import SwiftUI

struct MainView: View {
    @ObservedObject private var viewModel: MainViewModel
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var showTemplateCreator = false
    @State private var shouldDismiss = false
    
    init(sessionManager: SessionManager) {
        _viewModel = ObservedObject(wrappedValue: MainViewModel(sessionManager: sessionManager))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if let account = viewModel.currentAccount {
                AccountPickerView(account: account)
                    .background(Color.cardBackground)
                    .cornerRadius(8)
                
                HStack {
                    Text("Templates \(viewModel.templates.count)")
                        .font(.custom("Onest-Medium", size: 20))
                        .foregroundColor(.templateTitleColor)
                    Spacer()
                    Button(action: { showTemplateCreator = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.cardBackground)
                            .frame(width: 32, height: 32)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                }
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(viewModel.templates.enumerated()), id: \.element.id) { index, template in
                            TemplateRowView(template: template, index: index)
                        }
                    }
                }
            } else {
                NoAccountView(addNewAccount: viewModel.addNewAccount)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showTemplateCreator) {
            DatabaseNavigatorView(accessToken: viewModel.currentAccount?.accessToken ?? "", shouldDismiss: $shouldDismiss)
                .environment(\.managedObjectContext, managedObjectContext)
        }
        .background(Color(red: 0.969, green: 0.969, blue: 0.969)) // Equivalent to #2C2C2C
    
    }
}


