//
//  SessionManager.swift
//  NotionBuddySwift
//
//  Created by Harry on 16.07.2023.
//

import Foundation
import AuthenticationServices

class SessionManager: ObservableObject {
    @Published var webAuthSession: ASWebAuthenticationSession?
    @Published var accounts: [NotionAccount] = []
    @Published var selectedAccountIndex: Int = 0
    @Published var isAuthenticated: Bool = false
    var contextProvider = ContextProvider()
    
    func startWebAuthSession() {
        var urlString = "http://localhost:3000"
        // Check if a notion_buddy_id is stored in the user defaults
        if let notionBuddyID = UserDefaults.standard.string(forKey: "notionBuddyID") {
            urlString += "?notion_buddy_id=\(notionBuddyID)"
        }

        guard let url = URL(string: urlString) else {
            return
        }

        webAuthSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "notionbuddy") { callbackURL, error in
            guard error == nil, let successURL = callbackURL else {
                return
            }

            guard let notionBuddyID = URLComponents(string: successURL.absoluteString)?.queryItems?.first(where: { $0.name == "notion_buddy_id" })?.value else {
                return
            }

            // Store the notionBuddyID in user defaults
            UserDefaults.standard.set(notionBuddyID, forKey: "notionBuddyID")

            // Use the notion_buddy_id to fetch the account data
            DispatchQueue.main.async {
                self.fetchAccountData(notionBuddyID: notionBuddyID)
            }
        }

        webAuthSession?.presentationContextProvider = contextProvider
        webAuthSession?.start()
    }
    
    func fetchAccountData(notionBuddyID: String) {
        let urlString = "http://localhost:3000/get_accounts?notion_buddy_id=\(notionBuddyID)"

        guard let url = URL(string: urlString) else {
            print("Invalid URL for fetching account data.")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Failed to fetch account data. Error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("Failed to retrieve account data.")
                return
            }
            
            do {
                let decodedData = try JSONDecoder().decode(AccountsResponse.self, from: data)
                DispatchQueue.main.async {
                    self.accounts = decodedData.accounts
                    self.selectedAccountIndex = self.accounts.indices.first ?? 0
                    self.isAuthenticated = true
                }
            } catch {
                print("Failed to decode account data. Error: \(error.localizedDescription)")
            }
        }.resume()
    }
}
