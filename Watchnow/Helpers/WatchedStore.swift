//
//  WatchedStore.swift
//  Watchnow
//
//  What the user has actually seen.
//
//  Until now the app had no completion signal at all: a title was saved or
//  it wasn't, and the only way to say "done with this" was to delete it.
//  That made the watchlist a pile rather than a list you can finish, and it
//  left three things in this release unable to be honest — a "now streaming"
//  alert for a film you watched last month, a widget offering it up again
//  tonight, and a review prompt with no moment of satisfaction to attach to.
//
//  Stored as id → when, not as a set, for the same reason
//  `WatchlistManager.addedDates` is: the date is what lets anything later
//  say "you watched this in March" or count the last three. Synced, because
//  having seen something is a fact about the person, not about the phone.
//
//  Marking a title watched deliberately does *not* unsave it. The watchlist
//  becomes a record of what you meant to watch and what you did; throwing
//  the entry away at the moment it finally means something would be exactly
//  backwards.
//

import Foundation

@MainActor
enum WatchedStore {

    /// TMDB id (as String) → when it was marked (epoch seconds).
    @UserDefault("watchedAtDates", defaultValue: [:])
    private static var watchedAt: [String: Double]

    // MARK: - Reading

    static func isWatched(_ id: Int?) -> Bool {
        guard let id else { return false }
        return watchedAt[String(id)] != nil
    }

    static func watchedDate(forID id: Int) -> Date? {
        guard let epoch = watchedAt[String(id)] else { return nil }
        return Date(timeIntervalSince1970: epoch)
    }

    /// Every id marked watched. Used to filter decks and alert candidates
    /// without a lookup per title.
    static var watchedIDs: Set<Int> {
        Set(watchedAt.keys.compactMap(Int.init))
    }

    /// How many titles have been marked. The review prompt waits for the
    /// third one.
    static var count: Int { watchedAt.count }

    // MARK: - Writing

    /// Returns whether this was a new mark, so a caller can tell a first
    /// time from a re-tap without reading the store twice.
    @discardableResult
    static func markWatched(_ id: Int, now: Date = Date()) -> Bool {
        guard watchedAt[String(id)] == nil else { return false }
        watchedAt[String(id)] = now.timeIntervalSince1970
        return true
    }

    static func unmarkWatched(_ id: Int) {
        watchedAt.removeValue(forKey: String(id))
    }

    @discardableResult
    static func toggle(_ id: Int, now: Date = Date()) -> Bool {
        if isWatched(id) {
            unmarkWatched(id)
            return false
        }
        markWatched(id, now: now)
        return true
    }

    /// Unsaving a title forgets that it was watched, matching how the saved
    /// date, folder and alert exception are forgotten. Re-saving later means
    /// the user is starting over with it.
    static func forget(resultID id: Int) {
        unmarkWatched(id)
    }

    // MARK: - Reset

    /// Wipe everything — debug tooling and tests only.
    static func reset() {
        watchedAt = [:]
    }
}
