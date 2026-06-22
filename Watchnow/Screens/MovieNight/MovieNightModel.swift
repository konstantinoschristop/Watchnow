//
//  MovieNightModel.swift
//  Watchnow
//
//  "Movie Night" — the decision flow for "what do we watch tonight?".
//
//  Phase 1 is movies-only, pass-and-play: each person swipes the same deck
//  of candidates on one device, and the app surfaces the title(s) everyone
//  said yes to. No AI and no cross-device networking yet — candidates come
//  straight from TMDB's Discover endpoint (the same one the home tabs use)
//  blended with the user's watchlist.
//
//  This file holds the value types. The session logic lives in
//  `MovieNightViewModel`; the screens are the `MovieNight*View` files.
//

import Foundation

/// A mood chip on the setup screen. Each maps to a hand-tuned set of TMDB
/// *movie* genre IDs; when several moods are picked their genres are OR'd
/// together to widen the candidate pool rather than narrow it.
///
/// Genre IDs are movie-specific on purpose — TMDB uses a different genre
/// taxonomy for TV, which is why Phase 1 is scoped to movies.
struct Mood: Identifiable, Hashable {

    let id: String
    let label: String
    /// SF Symbol shown on the unselected chip.
    let symbol: String
    /// TMDB movie genre IDs this mood maps to.
    let genreIDs: [Int]

    static let all: [Mood] = [
        Mood(id: "funny",     label: "Funny",     symbol: "face.smiling",      genreIDs: [35]),
        Mood(id: "action",    label: "Action",    symbol: "flame.fill",        genreIDs: [28]),
        Mood(id: "scary",     label: "Scary",     symbol: "moon.stars.fill",   genreIDs: [27]),
        Mood(id: "romantic",  label: "Romantic",  symbol: "heart.fill",        genreIDs: [10749]),
        Mood(id: "tense",     label: "Tense",     symbol: "bolt.fill",         genreIDs: [53, 80]),
        Mood(id: "scifi",     label: "Sci-fi",    symbol: "atom",              genreIDs: [878]),
        Mood(id: "mystery",   label: "Mystery",   symbol: "magnifyingglass",   genreIDs: [9648]),
        Mood(id: "drama",     label: "Drama",     symbol: "cloud.rain.fill",   genreIDs: [18]),
        Mood(id: "feelgood",  label: "Feel-good", symbol: "sun.max.fill",      genreIDs: [35, 10402]),
        Mood(id: "family",    label: "Family",    symbol: "teddybear.fill",    genreIDs: [10751]),
        Mood(id: "fantasy",   label: "Fantasy",   symbol: "wand.and.stars",    genreIDs: [14]),
        Mood(id: "adventure", label: "Adventure", symbol: "map.fill",          genreIDs: [12]),
        Mood(id: "animated",  label: "Animated",  symbol: "paintpalette.fill", genreIDs: [16]),
        Mood(id: "western",   label: "Western",   symbol: "hat.cap.fill",      genreIDs: [37])
    ]
}

/// Runtime preference. Maps to TMDB's `with_runtime.lte` filter.
enum LengthBucket: String, CaseIterable, Identifiable {

    case quick
    case standard
    case any

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quick:    return "Quick"
        case .standard: return "~2 hrs"
        case .any:      return "Any"
        }
    }

    /// Secondary line shown under the label on the chip. Every bucket has one
    /// so the three duration chips stay the same height.
    var caption: String {
        switch self {
        case .quick:    return "< 90 min"
        case .standard: return "< 2½ hrs"
        case .any:      return "No limit"
        }
    }

    /// SF Symbol shown on the chip.
    var symbol: String {
        switch self {
        case .quick:    return "hare.fill"
        case .standard: return "clock.fill"
        case .any:      return "infinity"
        }
    }

    /// Upper runtime bound in minutes, or nil for "Any".
    var runtimeLTE: Int? {
        switch self {
        case .quick:    return 90
        case .standard: return 150
        case .any:      return nil
        }
    }
}

/// Everything captured on the setup screen — replayed verbatim on
/// "Deal again" so a re-roll keeps the same vibe.
struct MovieNightCriteria {

    var moodIDs: Set<String> = []
    var length: LengthBucket = .any
    var providerIDs: Set<Int> = []
    var playerCount: Int = 2

    /// Union of the genre IDs for every selected mood. Empty when no mood
    /// is picked — Discover then just returns broadly popular titles, which
    /// keeps the "one tap is enough" (or even zero) promise honest.
    var genreIDs: [Int] {
        let ids = Mood.all
            .filter { moodIDs.contains($0.id) }
            .flatMap(\.genreIDs)
        return Array(Set(ids)).sorted()
    }
}

/// Which screen the flow is currently showing.
enum MovieNightPhase {
    case setup
    case loading
    case swiping
    case results
    case empty   // criteria produced no usable candidates
    case error
}

/// TMDB movie genre id → display name. Movie genre IDs are stable, so this
/// static map lets the swipe card label a title's genres (which arrive as
/// `genre_ids` on the discover response) without an extra fetch.
enum MovieGenres {

    static let names: [Int: String] = [
        28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy",
        80: "Crime", 99: "Documentary", 18: "Drama", 10751: "Family",
        14: "Fantasy", 36: "History", 27: "Horror", 10402: "Music",
        9648: "Mystery", 10749: "Romance", 878: "Sci-Fi", 10770: "TV Movie",
        53: "Thriller", 10752: "War", 37: "Western"
    ]

    /// The first `limit` named genres for a result's `genre_ids`.
    static func names(for ids: [Int]?, limit: Int = 3) -> [String] {
        (ids ?? []).compactMap { names[$0] }.prefix(limit).map { $0 }
    }
}
