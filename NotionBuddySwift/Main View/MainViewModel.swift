import SwiftUI
import Combine

class MainViewModel: ObservableObject {
    @Published var selectedAccountIndex: Int
    @Published var accounts: [NotionAccount] = []
    
    private let sessionManager: SessionManager
    private var cancellables = Set<AnyCancellable>()
    
    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        self.selectedAccountIndex = sessionManager.selectedAccountIndex
        
        sessionManager.$accounts
            .assign(to: \.accounts, on: self)
            .store(in: &cancellables)
        
        sessionManager.$selectedAccountIndex
            .assign(to: \.selectedAccountIndex, on: self)
            .store(in: &cancellables)
        
        $selectedAccountIndex
            .dropFirst()
            .sink { [weak self] index in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if index >= 0 && index < self.accounts.count {
                        self.sessionManager.selectedAccountIndex = index
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    var currentAccount: NotionAccount? {
        guard !accounts.isEmpty, selectedAccountIndex >= 0, selectedAccountIndex < accounts.count else {
            return nil
        }
        return accounts[selectedAccountIndex]
    }
    
    func addNewAccount() {
        sessionManager.startWebAuthSession()
    }
}
