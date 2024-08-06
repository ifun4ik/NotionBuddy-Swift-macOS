import SwiftUI

class AccountPickerViewModel: ObservableObject {
    @Published var accounts: [NotionAccount] = []
    @Published var currentAccount: NotionAccount?
    
    private let sessionManager: SessionManager
    
    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        self.accounts = sessionManager.accounts
        self.currentAccount = sessionManager.currentAccount
    }
    
    func selectAccount(_ account: NotionAccount) {
        sessionManager.selectedAccountIndex = accounts.firstIndex(where: { $0.id == account.id }) ?? 0
        currentAccount = account
    }
    
    func addAccount() {
        // Implement account addition logic
    }
}
