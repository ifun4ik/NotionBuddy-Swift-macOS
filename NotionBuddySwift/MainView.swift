import SwiftUI
import SVGKit

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

    var emoji: String? {
        return icon?.emoji ?? icon?.external?.url
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
}

struct DatabasesResponse: Decodable {
    let results: [Database]
}

struct MainView: View {
    var accessToken: String
    @State private var searchResults: [SearchResult] = []
    @State private var searchQuery: String = ""
    @State private var isLoading: Bool = false

    var body: some View {
        VStack {
            HStack {
                TextField("Search for a database...", text: $searchQuery)
                    .padding()

                Button(action: {
                    self.search(query: searchQuery)
                }) {
                    Text("Search")
                }
            }

            if isLoading {
                ProgressView()
            } else if searchResults.isEmpty {
                Text("No results found.")
                    .foregroundColor(.gray)
            } else {
                List(searchResults) { result in
                    switch result {
                    case .database(let database):
                        HStack {
                            if let emoji = database.emoji, let url = URL(string: emoji) {
                                if let imageData = try? Data(contentsOf: url),
                                   let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                } else {
                                    Text(database.emoji ?? "")
                                }
                            } else {
                                Text(database.emoji ?? "")
                            }
                            Text(database.name)
                        }
                    }
                }
            }
        }
        .onAppear {
            fetchDatabases()
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

        print("Request URL: \(url)")
        print("Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Request Body: \(bodyString)")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                print("Failed to search. Error: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Response Status Code: \(httpResponse.statusCode)")
            }

            guard let data = data else {
                print("Failed to retrieve search results.")
                return
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response JSON: \(jsonString)")
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
}
