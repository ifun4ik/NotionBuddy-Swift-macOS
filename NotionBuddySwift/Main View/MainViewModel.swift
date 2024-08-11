import SwiftUI
import Combine
import CoreData

class MainViewModel: ObservableObject {
    @Published var selectedAccountIndex: Int
    @Published var accounts: [NotionAccount] = []
    @Published var templates: [Template] = []
    
    let sessionManager: SessionManager
    private var cancellables = Set<AnyCancellable>()
    let managedObjectContext: NSManagedObjectContext
    
    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        self.selectedAccountIndex = sessionManager.selectedAccountIndex
        self.managedObjectContext = PersistenceController.shared.container.viewContext
        
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
        
        fetchTemplates()
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
    
    func deleteTemplate(_ template: Template) {
        managedObjectContext.delete(template)
        do {
            try managedObjectContext.save()
            self.fetchTemplates()
        } catch {
            print("Failed to delete template: \(error)")
        }
    }
    
    func fetchTemplates() {
            let fetchRequest: NSFetchRequest<Template> = Template.fetchRequest()
            do {
                templates = try managedObjectContext.fetch(fetchRequest)
                fetchDatabaseInfo()  // This will fetch icons for all templates
            } catch {
                print("Failed to fetch templates: \(error)")
            }
        }

        func fetchDatabaseInfo() {
            for template in templates {
                if let databaseId = template.databaseId {
                    fetchDatabaseInfo(for: databaseId) { name, icon in
                        DispatchQueue.main.async {
                            template.databaseName = name
                            DatabaseIconManager.shared.setIcon(icon, for: databaseId)
                            self.objectWillChange.send()
                        }
                    }
                }
            }
        }

        func fetchDatabaseInfo(for databaseId: String, completion: @escaping (String?, DatabaseIcon?) -> Void) {
            guard let url = URL(string: "https://api.notion.com/v1/databases/\(databaseId)") else {
                completion(nil, nil)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(sessionManager.currentAccount?.accessToken ?? "")", forHTTPHeaderField: "Authorization")
            request.addValue("2021-08-16", forHTTPHeaderField: "Notion-Version")

            URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    completion(nil, nil)
                    return
                }
                
                let title = (json["title"] as? [[String: Any]])?.first?["plain_text"] as? String
                
                var databaseIcon: DatabaseIcon? = nil
                if let icon = json["icon"] as? [String: Any] {
                    if icon["type"] as? String == "emoji" {
                        databaseIcon = .emoji(icon["emoji"] as? String ?? "📄")
                    } else if icon["type"] as? String == "external" || icon["type"] as? String == "file",
                              let external = icon["external"] as? [String: Any],
                              let urlString = external["url"] as? String {
                        // Fetch the image data
                        if let imageUrl = URL(string: urlString) {
                            URLSession.shared.dataTask(with: imageUrl) { imageData, _, _ in
                                if let imageData = imageData {
                                    databaseIcon = .custom(imageData)
                                }
                                completion(title, databaseIcon)
                            }.resume()
                            return // Exit here as we're calling completion in the nested dataTask
                        }
                    }
                }
                
                completion(title, databaseIcon)
            }.resume()
        }
    }
