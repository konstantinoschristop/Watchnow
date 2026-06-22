//
//  WatchlistManager.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation

@propertyWrapper
struct UserDefault<T: Codable> {
    let key: String
    let defaultValue: T
    
    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    var wrappedValue: T {
        get {
            if let data = UserDefaults.standard.object(forKey: key) as? Data,
               let user = try? JSONDecoder().decode(T.self, from: data) {
                return user
                
            }
            
            return  defaultValue
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: key)
                // Mirror to iCloud for the keys that sync (watchlist, Movie
                // Night prefs); no-op for everything else.
                CloudSync.pushIfSynced(key)
            }
        }
    }
}

@MainActor
enum WatchlistManager {
    
    @UserDefault("watchlist", defaultValue: []) static var watchlist: [Result]
    
    @discardableResult
    static func addToWatchList(result: Result) -> Bool {

        if WatchlistManager.watchlist.contains(result) == false {
            WatchlistManager.watchlist.append(result)
            return true
        }
        return false
    }
    
    static func removeFromWatchList(result: Result) {

        if WatchlistManager.watchlist.contains(result) == true {
            if let index = WatchlistManager.watchlist.firstIndex(of: result) {
                WatchlistManager.watchlist.remove(at: index)
            }
        }
        // Drop the title's folder mapping too. If the user re-saves later
        // it should reappear in Uncategorized, not in the old folder.
        if let id = result.id {
            FolderManager.shared.forget(resultID: id)
        }
    }
    
    static func existsInWatchList(result: Result) -> Bool {
        
        return WatchlistManager.watchlist.contains(result)
    }
}
