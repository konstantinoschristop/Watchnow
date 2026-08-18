//
//  MovieCoachCache.swift
//  Watchnow
//
//  Remembers Coach's verdict per title so re-opening a details screen is
//  instant and doesn't burn a generation every time.
//
//  An entry is only reused when the prompt version *and* the context
//  signature still match, so the answer is regenerated whenever something
//  that could change it moves — the user saves/unsaves the title, sets a
//  reminder, files it in a folder, their genre profile shifts, the title
//  lands on a new service, or we ship new instructions.
//
//  Device-local by design (it's derived from private watchlist context, so
//  it is deliberately not in `CloudSync.syncedKeys`).
//

import Foundation

@MainActor
enum MovieCoachCache {

    /// Entries older than this are re-generated even if nothing else moved,
    /// so long-lived answers don't go stale as a title's status changes.
    private static let maxAge: TimeInterval = 14 * 24 * 3600
    /// Keeps the UserDefaults blob small; oldest entries are evicted first.
    private static let maxEntries = 60

    private struct Entry: Codable {
        let answer: MovieCoachAnswer
        let signature: String
        let promptVersion: Int
        let createdAt: Double
    }

    @UserDefault("movieCoachCache", defaultValue: [:])
    private static var entries: [String: Entry]

    static func key(mediaType: String, id: String) -> String {
        "\(mediaType).\(id)"
    }

    /// Cached answer for this title, or nil when absent, stale, superseded by
    /// a new prompt version, or invalidated by changed context.
    static func read(key: String, signature: String) -> MovieCoachAnswer? {
        guard let entry = entries[key],
              entry.promptVersion == MovieCoachService.promptVersion,
              entry.signature == signature,
              Date().timeIntervalSince1970 - entry.createdAt < maxAge
        else { return nil }
        return entry.answer
    }

    static func write(_ answer: MovieCoachAnswer, key: String, signature: String) {
        var store = entries
        store[key] = Entry(answer: answer,
                           signature: signature,
                           promptVersion: MovieCoachService.promptVersion,
                           createdAt: Date().timeIntervalSince1970)

        if store.count > maxEntries {
            let survivors = store.sorted { $0.value.createdAt > $1.value.createdAt }
                .prefix(maxEntries)
            store = Dictionary(uniqueKeysWithValues: survivors.map { ($0.key, $0.value) })
        }
        entries = store
    }

    /// Drops a single title's answer — used by "Ask again".
    static func invalidate(key: String) {
        var store = entries
        store.removeValue(forKey: key)
        entries = store
    }
}
