//
//  UserDefaultsLogger.swift
//  NotionBuddySwift
//
//  Created by Harry on 17.07.2023.
//

import Foundation

class UserDefaultsLogger {
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = UserDefaults.standard) {
        self.userDefaults = userDefaults
    }
    
    func set(_ value: Any?, forKey defaultName: String) {
        print("Setting \(String(describing: value)) for key \(defaultName)")
        userDefaults.set(value, forKey: defaultName)
    }
    
    func removeObject(forKey defaultName: String) {
        print("Removing object for key \(defaultName)")
        userDefaults.removeObject(forKey: defaultName)
    }
    
    // Add other methods as needed for different types of UserDefaults operations
    
    // Example:
    // func string(forKey defaultName: String) -> String? {
    //     print("Getting string for key \(defaultName)")
    //     return userDefaults.string(forKey: defaultName)
    // }
}
