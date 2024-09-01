//
//  DatabaseServices.swift
//  NotionBuddySwift
//
//  Created by Harry Alexandroff on 01.09.2024.
//

import Foundation

class DatabaseService {
    let accessToken: String
    
    init(accessToken: String) {
        self.accessToken = accessToken
    }
    
    func fetchRelatedDatabaseTitles(for databaseId: String, completion: @escaping ([String: String]) -> Void) {
        guard let url = URL(string: "https://api.notion.com/v1/databases/\(databaseId)/query") else {
            completion([:])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("2021-08-16", forHTTPHeaderField: "Notion-Version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching related database titles: \(error)")
                completion([:])
                return
            }
            
            guard let data = data else {
                completion([:])
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let results = json["results"] as? [[String: Any]] {
                    var titles: [String: String] = [:]
                    for result in results {
                        if let id = result["id"] as? String,
                           let properties = result["properties"] as? [String: Any],
                           let titleProperty = properties.first(where: { $0.value is [String: Any] && ($0.value as? [String: Any])?["title"] is [[String: Any]] }),
                           let titleArray = (titleProperty.value as? [String: Any])?["title"] as? [[String: Any]],
                           let firstTitle = titleArray.first,
                           let plainText = firstTitle["plain_text"] as? String {
                            titles[id] = plainText
                        }
                    }
                    completion(titles)
                } else {
                    completion([:])
                }
            } catch {
                print("Error parsing related database titles: \(error)")
                completion([:])
            }
        }.resume()
    }
}
