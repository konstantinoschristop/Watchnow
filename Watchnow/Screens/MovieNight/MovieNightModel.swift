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
        Mood(id: "funny",     label: String(localized: "Funny", comment: "Movie Night mood"),     symbol: "face.smiling",      genreIDs: [35]),
        Mood(id: "action",    label: String(localized: "Action", comment: "Movie Night mood"),    symbol: "flame.fill",        genreIDs: [28]),
        Mood(id: "scary",     label: String(localized: "Scary", comment: "Movie Night mood"),     symbol: "moon.stars.fill",   genreIDs: [27]),
        Mood(id: "romantic",  label: String(localized: "Romantic", comment: "Movie Night mood"),  symbol: "heart.fill",        genreIDs: [10749]),
        Mood(id: "tense",     label: String(localized: "Tense", comment: "Movie Night mood"),     symbol: "bolt.fill",         genreIDs: [53, 80]),
        Mood(id: "scifi",     label: String(localized: "Sci-fi", comment: "Movie Night mood"),    symbol: "atom",              genreIDs: [878]),
        Mood(id: "mystery",   label: String(localized: "Mystery", comment: "Movie Night mood"),   symbol: "magnifyingglass",   genreIDs: [9648]),
        Mood(id: "drama",     label: String(localized: "Drama", comment: "Movie Night mood"),     symbol: "cloud.rain.fill",   genreIDs: [18]),
        Mood(id: "feelgood",  label: String(localized: "Feel-good", comment: "Movie Night mood"), symbol: "sun.max.fill",      genreIDs: [35, 10402]),
        Mood(id: "family",    label: String(localized: "Family", comment: "Movie Night mood"),    symbol: "teddybear.fill",    genreIDs: [10751]),
        Mood(id: "fantasy",   label: String(localized: "Fantasy", comment: "Movie Night mood"),   symbol: "wand.and.stars",    genreIDs: [14]),
        Mood(id: "adventure", label: String(localized: "Adventure", comment: "Movie Night mood"), symbol: "map.fill",          genreIDs: [12]),
        Mood(id: "animated",  label: String(localized: "Animated", comment: "Movie Night mood"),  symbol: "paintpalette.fill", genreIDs: [16]),
        Mood(id: "western",   label: String(localized: "Western", comment: "Movie Night mood"),   symbol: "hat.cap.fill",      genreIDs: [37])
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
        case .quick:    return String(localized: "Quick", comment: "Movie Night length option: a short film")
        case .standard: return String(localized: "~2 hrs", comment: "Movie Night length option: about two hours. Keep it short.")
        case .any:      return String(localized: "Any", comment: "Movie Night length option: any length")
        }
    }

    /// Secondary line shown under the label on the chip. Every bucket has one
    /// so the three duration chips stay the same height.
    var caption: String {
        switch self {
        case .quick:    return String(localized: "< 90 min", comment: "Movie Night length caption: under 90 minutes. Keep it short.")
        case .standard: return String(localized: "< 2½ hrs", comment: "Movie Night length caption: under two and a half hours. Keep it short.")
        case .any:      return String(localized: "No limit", comment: "Movie Night length caption")
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

    /// `tmdbGenreDisplayNames`, plus the two movie genres the feed's table
    /// leaves out.
    static let names: [Int: String] = tmdbGenreDisplayNames.merging([
        10402: String(localized: "Music", comment: "Genre"),
        10770: String(localized: "TV Movie", comment: "Genre: a film made for television"),
    ]) { current, _ in current }

    /// The first `limit` named genres for a result's `genre_ids`.
    static func names(for ids: [Int]?, limit: Int = 3) -> [String] {
        (ids ?? []).compactMap { names[$0] }.prefix(limit).map { $0 }
    }
}
