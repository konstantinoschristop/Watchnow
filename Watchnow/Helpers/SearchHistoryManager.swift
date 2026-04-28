//
//  SearchHistoryManager.swift
//  Watchnow
//
//  Persists the user's last 10 search queries in UserDefaults.
//  Mirrors the WatchlistManager enum pattern exactly.
//

import Foundation

@MainActor
enum SearchHistoryManager {

    @UserDefault("recentSearches", defaultValue: []) static var recentSearches: [String]

    /// Prepends `query`, deduplicates, caps at 10.
    static func addSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        var current = recentSearches
        current.removeAll { $0.lowercased() == trimmed.lowercased() }
        current.insert(trimmed, at: 0)
        recentSearches = Array(current.prefix(10))
    }

    static func removeSearch(_ query: String) {
        recentSearches = recentSearches.filter { $0 != query }
    }

    static func clearAll() {
        recentSearches = []
    }
}
