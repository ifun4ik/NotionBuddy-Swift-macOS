//import SwiftUI
//import CoreData
//
//class TemplateNavigatorViewModel: ObservableObject {
//    @Published var templates: [Template] = []
//    @Published var showDatabaseNavigatorView = false
//    @Published var selectedTemplate: Template?
//    @Published var userInfo: UserInfo
//    
//    private var managedObjectContext: NSManagedObjectContext
//    let sessionManager: SessionManager
//    
//    init(managedObjectContext: NSManagedObjectContext, sessionManager: SessionManager) {
//        self.managedObjectContext = managedObjectContext
//        self.sessionManager = sessionManager
//        
//        let currentAccount = sessionManager.accounts[sessionManager.selectedAccountIndex]
//        self.userInfo = UserInfo(name: currentAccount.name,
//                                 email: currentAccount.email,
//                                 avatarUrl: currentAccount.avatarUrl)
//        fetchTemplates()
//    }
//    
//    func fetchTemplates() {
//        let fetchRequest: NSFetchRequest<Template> = Template.fetchRequest()
//        do {
//            templates = try managedObjectContext.fetch(fetchRequest)
//        } catch {
//            print("Failed to fetch templates: \(error)")
//        }
//    }
//    
//    func deleteTemplate(at offsets: IndexSet) {
//        for index in offsets {
//            let template = templates[index]
//            managedObjectContext.delete(template)
//        }
//        do {
//            try managedObjectContext.save()
//            fetchTemplates()
//        } catch {
//            print("Failed to delete template: \(error)")
//        }
//    }
//    
//    func addTemplate() {
//        showDatabaseNavigatorView = true
//    }
//    
//    func editTemplate(_ template: Template) {
//        selectedTemplate = template
//    }
//}
//
//struct UserInfo {
//    let name: String
//    let email: String
//    let avatarUrl: String?
//}
