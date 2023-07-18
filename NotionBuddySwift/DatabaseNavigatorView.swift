import SwiftUI
import SDWebImageSwiftUI
import SDWebImageSVGCoder
import CoreData

enum SearchResult: Identifiable {
    case database(Database)

    var id: String {
        switch self {
        case .database(let database):
            return database.id
        }
    }
}

struct Database: Identifiable, Decodable {
    let id: String
    let title: [DatabaseTitle]
    let icon: DatabaseIcon?
    let properties: [String: Property]?

    var iconURL: URL? {
        guard let iconURLString = icon?.external?.url else {
            return nil
        }
        return URL(string: iconURLString)
    }

    var name: String {
        return title.first?.text?.content ?? "Unnamed Database"
    }

    struct DatabaseTitle: Decodable {
        let type: String
        let text: DatabaseContent?

        struct DatabaseContent: Decodable {
            let content: String
        }
    }

    struct DatabaseIcon: Decodable {
        let type: String
        let emoji: String?
        let external: ExternalIcon?

        struct ExternalIcon: Decodable {
            let url: String
        }
    }

    struct Property: Decodable {
        let id: String
        let name: String
        let type: String
        let people: People?
        let checkbox: Checkbox?
        let number: Number?
        let richText: RichText?

        struct People: Decodable {
            // Add relevant properties
        }

        struct Checkbox: Decodable {
            // Add relevant properties
        }

        struct Number: Decodable {
            let format: String
        }

        struct RichText: Decodable {
            // Add relevant properties
        }
    }
}

struct DatabasesResponse: Decodable {
    let results: [Database]
}

struct DatabaseNavigatorView: View {
    var accessToken: String
    @State private var searchResults: [SearchResult] = []
    @State private var searchQuery: String = ""
    @State private var isLoading: Bool = false
    @State private var selectedDatabase: Database? = nil
    @State private var showTemplateCreator = false
    @Environment(\.managedObjectContext) private var managedObjectContext

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                TextField("Search for a database...", text: $searchQuery)
                Button(action: {
                    self.search(query: searchQuery)
                }) {
                    Text("Search")
                }
            }
            .padding([.all], 8)

            if isLoading {
                ProgressView()
            } else if searchResults.isEmpty {
                Text("No results found.")
                    .foregroundColor(.gray)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(searchResults) { result in
                            switch result {
                            case .database(let database):
                                DatabaseListItemView(database: database)
                                    .background(selectedDatabase?.id == database.id ? Color.accentColor : Color.clear)
                                    .onTapGesture {
                                        self.selectedDatabase = database
                                        self.logProperties(database: database)
                                        self.showTemplateCreator = true
                                    }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            SDImageCodersManager.shared.addCoder(SDImageSVGCoder.shared)
            fetchDatabases()
        }
        .sheet(isPresented: $showTemplateCreator) {
            if let selectedDatabase = selectedDatabase {
                TemplateCreatorView(database: selectedDatabase)
                    .environment(\.managedObjectContext, self.managedObjectContext)
            }
        }
    }

    func fetchDatabases() {
        guard let url = URL(string: "https://api.notion.com/v1/databases") else {
            return
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("2021-05-13", forHTTPHeaderField: "Notion-Version")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to fetch databases. Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("Failed to retrieve databases.")
                return
            }

            do {
                let decodedData = try JSONDecoder().decode(DatabasesResponse.self, from: data)
                DispatchQueue.main.async {
                    self.searchResults = decodedData.results.map(SearchResult.database)
                }
            } catch {
                print("Failed to decode databases. Error: \(error.localizedDescription)")
            }
        }.resume()
    }

    func search(query: String) {
        isLoading = true

        guard let url = URL(string: "https://api.notion.com/v1/search") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("2021-05-13", forHTTPHeaderField: "Notion-Version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let json: [String: Any] = [
            "query": query,
            "filter": [
                "value": "database",
                "property": "object"
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: json)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                print("Failed to search. Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("Failed to retrieve search results.")
                return
            }

            do {
                let decodedData = try JSONDecoder().decode(DatabasesResponse.self, from: data)
                DispatchQueue.main.async {
                    self.searchResults = decodedData.results.map(SearchResult.database)
                }
            } catch {
                print("Failed to decode search results. Error: \(error)")
            }
        }.resume()
    }

    func logProperties(database: Database) {
        if let properties = database.properties {
            for (name, property) in properties {
                print("Property Name: \(name)")
                print("Property ID: \(property.id)")
                print("Property Type: \(property.type)")
                // Log additional relevant properties based on the property type
            }
        }
    }
}

struct DatabaseListItemView: View {
    let database: Database
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 8) {
                if let iconURL = database.iconURL {
                    WebImage(url: iconURL)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else if let emoji = database.icon?.emoji {
                    Text(emoji)
                        .font(.system(size: 24))
                } else {
                    Text("🙈")
                        .font(.system(size: 24))
                }
                
                Text(database.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding([.all], 8)
            
            Divider()
        }
    }
}
