import SwiftUI

struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    @ObservedObject var sessionManager: SessionManager
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var showTemplateCreator = false
    
    init(sessionManager: SessionManager) {
        self._sessionManager = ObservedObject(wrappedValue: sessionManager)
        _viewModel = StateObject(wrappedValue: MainViewModel(sessionManager: sessionManager))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if !sessionManager.accounts.isEmpty {
                AccountPickerView(sessionManager: sessionManager)
                
                TemplateListView(viewModel: viewModel, addNewTemplate: {
                    showTemplateCreator = true
                })
            } else {
                NoAccountView(addNewAccount: viewModel.addNewAccount)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showTemplateCreator) {
            DatabaseNavigatorView(accessToken: viewModel.currentAccount?.accessToken ?? "", onDismiss: {
                showTemplateCreator = false
                viewModel.fetchTemplates()
            })
            .environment(\.managedObjectContext, managedObjectContext)
            .frame(width: 352, height: 400)
            .fixedSize()
        }
        .background(Color(red: 0.968, green: 0.968, blue: 0.968))
        .onAppear {
            viewModel.fetchTemplates()
        }
    }
}

// MARK: - Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let mockSessionManager = SessionManager()
        let mockViewModel = MainViewModel(sessionManager: mockSessionManager)
        
        // Set up mock data
        mockSessionManager.accounts = [NotionAccount(
            id: "1",
            notionBuddyID: "123",
            accessToken: "mock_token",
            name: "John Doe",
            email: "john@example.com",
            avatarUrl: "https://example.com/avatar.jpg",
            workspaceName: "My Workspace",
            workspaceIcon: nil
        )]
        mockSessionManager.selectedAccountIndex = 0
        
        // Create a mock managed object context
        let mockContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        
        // Create mock templates
        let mockTemplates = (0..<3).map { index -> Template in
            let template = Template(context: mockContext)
            template.name = "Template \(index + 1)"
            template.databaseId = "db_\(index + 1)"
            return template
        }
        
        // Set the mock templates in the view model
        mockViewModel.templates = mockTemplates
        
        return MainView(sessionManager: mockSessionManager)
            .environmentObject(mockViewModel)
            .environment(\.managedObjectContext, mockContext)
    }
}
