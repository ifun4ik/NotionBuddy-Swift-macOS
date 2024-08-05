import SwiftUI
import Combine

class LoginViewModel: ObservableObject {
    @Published var isAuthenticating = false
    @Published var error: LoginError?
    
    private let sessionManager: SessionManager
    private var cancellables = Set<AnyCancellable>()
    
    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        
        sessionManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.isAuthenticating = false
                }
            }
            .store(in: &cancellables)
    }
    
    func authenticate() {
        isAuthenticating = true
        sessionManager.startWebAuthSession()
    }
    
    func checkExistingAuthentication() {
        if let notionBuddyID = UserDefaults.standard.string(forKey: "notionBuddyID") {
            isAuthenticating = true
            sessionManager.fetchAccountData(notionBuddyID: notionBuddyID)
        }
    }
}

struct LoginError: Identifiable {
    let id = UUID()
    let message: String
}
