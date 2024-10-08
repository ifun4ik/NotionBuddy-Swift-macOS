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
        let type: String
        let name: String
        let select: SelectOptions?
        let multi_select: MultiSelectOptions?
        let people: People?
        let checkbox: Checkbox?
        let number: Number?
        let richText: RichText?
        let title: Title?
        let url: Url?
        let status: Status?
        
        struct Status: Decodable {
            let options: [Option]
            let groups: [Group]
            
            struct Option: Decodable {
                let id: String
                let name: String
                let color: String
            }
            
            struct Group: Decodable {
                let id: String
                let name: String
                let color: String
                let option_ids: [String]
            }
        }

        struct People: Decodable {}
        struct Checkbox: Decodable {}
        struct Number: Decodable { let format: String }
        struct RichText: Decodable {}
        struct Title: Decodable {}
        struct Url: Decodable {}

        struct SelectOptions: Decodable {
            let options: [Option]
            struct Option: Decodable {
                let id: String
                let name: String
                let color: String
            }
        }

        struct MultiSelectOptions: Decodable {
            let options: [Option]
            struct Option: Decodable {
                let id: String
                let name: String
                let color: String
            }
        }
    }
}

struct DatabasesResponse: Decodable {
    let results: [Database]
}

struct DatabaseNavigatorView: View {
    var accessToken: String
    var onDismiss: () -> Void
    @State private var searchResults: [SearchResult] = []
    @State private var searchQuery: String = ""
    @State private var isLoading: Bool = false
    @State private var selectedDatabase: Database? = nil
    @State private var showTemplateCreator = false
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Pick a database")
                    .font(.custom("Onest-Medium", size: 20))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.textPrimary)
                    
                    TextField("Search", text: $searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.custom("Onest-Regular", size: 14))
                        .foregroundColor(.textPrimary)
                }
                .frame(width: 136, height: 32)
                .padding(.horizontal, 10)
                .background(Color(.white))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Divider()
                .overlay(Color.divider)
            
            if isLoading {
                ProgressView()
                    .frame(width: 352)
                Spacer()
            } else if searchResults.isEmpty {
                Text("No results found.")
                    .foregroundColor(.gray)
                    .frame(width: 352)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults) { result in
                            switch result {
                            case .database(let database):
                                DatabaseListItemView(database: database)
                                    .background(selectedDatabase?.id == database.id ? Color.accentColor.opacity(0.1) : Color.clear)
                                    .onTapGesture {
                                        self.selectedDatabase = database
                                        self.logProperties(database: database)
                                        self.showTemplateCreator = true
                                    }
                            }
                        }
                    }
                }
                .frame(width: 352)
                Spacer()
            }
        }
//        .frame(width: 352, height: 300)
        .background(Color.white)
        .onAppear {
            SDImageCodersManager.shared.addCoder(SDImageSVGCoder.shared)
            fetchDatabases()
        }
        .onChange(of: searchQuery) { newValue in
            search(query: newValue)
        }
        .sheet(isPresented: $showTemplateCreator) {
            if let selectedDatabase = selectedDatabase {
                TemplateCreatorView(database: selectedDatabase, onSave: {
                    showTemplateCreator = false
                    onDismiss()
                })
                .environment(\.managedObjectContext, self.managedObjectContext)
                .background(Color.white)
                .frame(width: 352, height: 480)
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

                if let select = property.select {
                    print("Select Options:")
                    for option in select.options {
                        print("Option Name: \(option.name)")
                        print("Option ID: \(option.id)")
                        print("Option Color: \(option.color)")
                    }
                }

                if let multi_select = property.multi_select {
                    print("MultiSelect Options:")
                    for option in multi_select.options {
                        print("Option Name: \(option.name)")
                        print("Option ID: \(option.id)")
                        print("Option Color: \(option.color)")
                    }
                }

                if let status = property.status {
                    print("Status Options:")
                    for option in status.options {
                        print("Option Name: \(option.name)")
                        print("Option ID: \(option.id)")
                        print("Option Color: \(option.color)")
                    }
                    print("Status Groups:")
                    for group in status.groups {
                        print("Group Name: \(group.name)")
                        print("Group ID: \(group.id)")
                        print("Group Color: \(group.color)")
                        print("Group Option IDs: \(group.option_ids.joined(separator: ", "))")
                    }
                }
            }
        }
    }
}

struct DatabaseListItemView: View {
    let database: Database
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let iconURL = database.iconURL {
                    WebImage(url: iconURL)
                        .resizable()
                        .placeholder {
                            Color.gray.opacity(0.2)
                        }
                        .indicator(.activity)
                        .transition(.fade(duration: 0.5))
                        .frame(width: 20, height: 20)
                } else if let emoji = database.icon?.emoji {
                    Text(emoji)
                        .font(.custom("Onest-Medium", size: 16))
                } else {
                    Image(systemName: "doc.text")
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 32, height: 32)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            
            Text(database.name)
                .font(.custom("Onest-Medium", size: 16))
                .foregroundColor(.textPrimary)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}
