//
//  StreamingPreferences.swift
//  Watchnow
//
//  Remembers which streaming services the user subscribes to so "Movie
//  Night" can pre-fill the "Where" row instead of asking every session.
//  Set once, edit anytime. Persisted with the same `@UserDefault` wrapper
//  the watchlist uses (declared in WatchlistManager.swift).
//

import Foundation

@MainActor
enum StreamingPreferences {

    /// TMDB provider IDs (e.g. Netflix = 8) the user has said they have.
    @UserDefault("movieNightProviderIDs", defaultValue: [])
    static var providerIDs: [Int]

    /// True once the user has picked at least one service. Drives whether
    /// the setup screen shows the full "Which do you have?" picker (first
    /// run) or the compact pre-filled row with an Edit affordance.
    static var hasMadeSelection: Bool { !providerIDs.isEmpty }

    /// Posted after `save(_:)`, for screens that order things by the user's
    /// services. The feed puts theirs first in its chip bar, and Settings —
    /// where they change them — is a sheet over the feed, which gets no
    /// appear event when it closes.
    static let didChange = Notification.Name("StreamingPreferencesDidChange")

    static func save(_ ids: Set<Int>) {
        providerIDs = Array(ids).sorted()
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
