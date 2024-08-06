import SwiftUI

class AddTemplateViewModel: ObservableObject {
    @Published var showingAddTemplate = false
    
    func addTemplate() {
        showingAddTemplate = true
    }
}
