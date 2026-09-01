//
//  UpcomingMoviesModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation
import SwiftUI

enum ViewSections {
    case upcomingMovies
    case popularMovies
    case trendingMovies
    case latestMovies
    case topRatedMovies
    case streamingServicesMovies

    case popularSeries
    case airingTodaySeries
    case trendingSeries
    case latestSeries
    case topRatedSeries
    case streamingServicesSeries
}

extension ViewSections {
    var screenType: ScreenTypes {
        switch self {
        case .upcomingMovies, .popularMovies, .trendingMovies, .latestMovies, .topRatedMovies, .streamingServicesMovies:
            return .movie
        case .popularSeries, .airingTodaySeries, .trendingSeries, .latestSeries, .topRatedSeries, .streamingServicesSeries:
            return .tv
        }
    }

    /// Emoji-prefixed title kept for any legacy caller. New layouts use
    /// `cleanTitle` + `themeIcon` so the icon is a proper SF Symbol that
    /// can be tinted, animated, and styled consistently.
    var title: String {
        switch self {
        case .trendingMovies: return "🔥 Hot Right Now"
        case .latestMovies: return "🎟️ In Theaters Now"
        case .popularMovies: return "Most Watched"
        case .upcomingMovies: return "Coming Soon"
        case .topRatedMovies: return "🏆 Top 10 of All Time"
        case .streamingServicesMovies: return "Browse by Streaming"

        case .trendingSeries: return "🔥 Binge-Worthy Today"
        case .airingTodaySeries: return "Fresh Episodes"
        case .popularSeries: return "Most Watched"
        case .latestSeries: return "Critics' Choice"
        case .topRatedSeries: return "🏆 Top 10 of All Time"
        case .streamingServicesSeries: return "Browse by Streaming"
        }
    }

    /// Emoji-free variant. The emoji is replaced by a tinted SF Symbol
    /// rendered alongside the title in `SectionHeaderView`, which gives
    /// us a proper tint, a larger hit-size, and the option to animate
    /// the glyph (e.g. the live pulse on trending).
    var cleanTitle: String {
        switch self {
        case .trendingMovies: return "Hot Right Now"
        case .latestMovies: return "In Theaters Now"
        case .popularMovies, .popularSeries: return "Most Watched"
        case .upcomingMovies: return "Coming Soon"
        case .trendingSeries: return "Binge-Worthy Today"
        case .airingTodaySeries: return "Fresh Episodes"
        case .latestSeries: return "Critics' Choice"
        case .topRatedMovies, .topRatedSeries: return "Top 10 of All Time"
        case .streamingServicesMovies, .streamingServicesSeries: return "Browse by Streaming"
        }
    }

    /// Section-specific SF Symbol. Rendered at the leading edge of the
    /// header; carries the section's personality without bloating the
    /// title with emoji.
    var themeIcon: String {
        switch self {
        case .trendingMovies, .trendingSeries: return "flame.fill"
        case .latestMovies:                    return "ticket.fill"
        case .popularMovies, .popularSeries:   return "eye.fill"
        case .upcomingMovies:                  return "calendar"
        case .airingTodaySeries:               return "sparkles"
        case .latestSeries:                    return "star.circle.fill"
        case .topRatedMovies, .topRatedSeries: return "trophy.fill"
        case .streamingServicesMovies, .streamingServicesSeries: return "play.tv.fill"
        }
    }

    /// Tint applied to both the header's 3pt rail and the section icon.
    /// Tint for the section header icon. Trending paints red — it's the
    /// "live, hot right now" headliner and earns the attention colour.
    /// Every other section uses the brand accent so the screen reads as
    /// one design system, with the SF Symbol shape (flame, eye, calendar)
    /// doing the section differentiation.
    var themeColor: Color {
        switch self {
        case .trendingMovies, .trendingSeries: return .red
        default:                               return .accentColor
        }
    }

    /// Trending sections show a small live-pulse dot so the row reads
    /// as real-time, not canned.
    var isTrending: Bool {
        switch self {
        case .trendingMovies, .trendingSeries: return true
        default: return false
        }
    }

    var isTopView: Bool { isTrending }

    /// Rendered as a vertical list of rich rows instead of a horizontal
    /// poster scroll. Kept at the same positional slot (the "new / fresh"
    /// section — position 2) on both the Movies and Series screens so the
    /// two tabs stay structurally symmetric: trending → list → most-watched
    /// → discover.
    var isListSection: Bool {
        switch self {
        case .latestMovies, .airingTodaySeries: return true
        default: return false
        }
    }

    /// Top-10 ranked list with giant rank numerals on the leading edge.
    /// The "scroll-payoff" section at the very bottom of each tab —
    /// rewards the user for getting all the way down with the most
    /// distinctive layout in the app.
    var isTopTenSection: Bool {
        switch self {
        case .topRatedMovies, .topRatedSeries: return true
        default: return false
        }
    }

    /// Horizontal tile row of streaming-service logos. Tapping a tile
    /// opens a sheet that discovers titles available on that service in
    /// the user's region — "I have Netflix, what's on it?"
    var isStreamingServicesSection: Bool {
        switch self {
        case .streamingServicesMovies, .streamingServicesSeries: return true
        default: return false
        }
    }
}

struct GenericResultResponse: Codable, Equatable {
    var results: [Result]
    var total_pages: Int?
    
    static func == (lhs: GenericResultResponse, rhs: GenericResultResponse) -> Bool {
        return lhs.results == rhs.results
    }
}

// MARK: - Result
struct Result: Codable, Hashable, Equatable {

    // A saved watchlist entry is a long-lived copy of a TMDB record, and TMDB
    // keeps editing the record: posters get replaced, ratings drift, dates
    // get announced, titles get corrected. The fields the app actually
    // *renders* are therefore `var`, so a stored entry can be brought up to
    // date from a details fetch — see `refresh(from:)`.
    //
    // `id` stays immutable, which is what makes the refresh safe: `==` and
    // `hash(into:)` are defined on `id` alone, so nothing that keys off a
    // Result — `ForEach` identity, folder membership, saved dates, provider
    // records — notices a metadata change.

    var backdrop_path: String?
    var first_air_date: String?
    var genre_ids: [Int]?
    let id: Int?
    let original_title: String?
    var name: String?
    let origin_country: [String]?
    let original_language, original_name: String?
    var overview: String?
    let popularity: Double?
    var poster_path: String?
    var release_date: String?
    var title: String?
    let video: Bool?
    var vote_average: Double?
    var vote_count: Int?
    var media_type: String?
    let profile_path: String?
    let castID: Int?
    var runtime: Int?
    /// Populated by TMDB's multi-search endpoint for person results.
    /// Contains a short reel of the actor's most notable work.
    let known_for: [Result]?
    
    static func == (lhs: Result, rhs: Result) -> Bool {
        return lhs.id == rhs.id
    }

    /// Hashes the TMDB id alone, matching `==`.
    ///
    /// Must be written out: declaring `==` by hand does *not* suppress the
    /// compiler's synthesis of `hash(into:)`, so without this the two
    /// disagreed — two values with the same id but any differing field
    /// (a re-decode, an iCloud merge, a `media_type` stamp) compared equal
    /// yet hashed differently, which breaks `Hashable`'s contract. The
    /// visible cost was in SwiftUI: every `ForEach(…, id: \.self)` over
    /// results keyed cell identity on the whole value, so a cell was torn
    /// down and rebuilt — poster re-fading, per-cell `@State` reset —
    /// whenever an unrelated field changed underneath it.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }


    func getResultTitle() -> String {
        return (name ?? title) ?? "- -"
    }
    
    func getResultPosterURL() -> URL {
        let posterURL = (poster_path ?? backdrop_path ?? profile_path) ?? ""
        return URL(string: API.Common.imageUrl(imageId: posterURL))
            ?? URL(string: API.baseURL)!
    }

    func getPosterURL() -> URL {
        let posterURL = poster_path ?? ""
        return URL(string: API.Common.imageUrl(imageId: posterURL))
            ?? URL(string: API.baseURL)!
    }

    func getBackdropURL() -> URL {
        let posterURL = backdrop_path ?? ""
        return URL(string: API.Common.imageUrl(imageId: posterURL))
            ?? URL(string: API.baseURL)!
    }
    
    /// Raw TMDB media kind as a display string.
    ///
    /// Note the fall-through: *anything* without a recognised `media_type`
    /// reads as "Actor". That's correct for multi-search, where people
    /// always arrive tagged `person`, but wrong for a saved title from a
    /// build that didn't stamp the field — prefer `isPerson` for routing
    /// decisions and `inferredScreenType` for saved titles.
    func getMediaType() -> String {
        if media_type == "movie" {
            return "Movie"
        } else if media_type == "tv" {
            return "TV Series"
        } else {
            return "Actor"
        }
    }

    /// Brings this copy up to date from a details fetch.
    ///
    /// Only ever *adds* information: every assignment is guarded on the fresh
    /// value being present, and non-empty for strings, so a partial or
    /// half-failed response can never blank out something the app already
    /// knew. Same rule `ChangeClassifier.updatedSnapshot` follows, and for
    /// the same reason — a missing field means "not fetched", not "empty".
    ///
    /// Deliberately narrow: identity, popularity and the person-only fields
    /// are left alone. This exists to stop a saved poster going stale, not to
    /// re-derive the entry.
    mutating func refresh(from details: ResultDetailsResponse) {
        if let path = details.poster_path, !path.isEmpty { poster_path = path }
        if let path = details.backdrop_path, !path.isEmpty { backdrop_path = path }
        if let value = details.title, !value.isEmpty { title = value }
        if let value = details.name, !value.isEmpty { name = value }
        if let value = details.overview, !value.isEmpty { overview = value }
        if let value = details.release_date, !value.isEmpty { release_date = value }
        if let value = details.first_air_date, !value.isEmpty { first_air_date = value }
        if let value = details.vote_average { vote_average = value }
        if let value = details.vote_count { vote_count = value }
        if let value = details.runtime { runtime = value }
        // The details endpoint returns genre objects where the list
        // endpoints return bare ids; the app reads ids everywhere else.
        if let ids = details.genres?.compactMap(\.id), !ids.isEmpty { genre_ids = ids }
    }

    /// Whether this result is genuinely a person.
    ///
    /// Tested positively rather than as "not a movie or series". Search's
    /// multi endpoint always tags people `person` (and `cleanUpResults`
    /// drops any that don't have both that tag and a profile image), so the
    /// positive test is exact — while the negative one swept up untagged
    /// saved titles and routed them to the person UI, where a watchlist row
    /// lost its rating, its overview and, because actors have no trailing
    /// swipe action, any way to remove it.
    var isPerson: Bool {
        media_type == "person"
    }
    
    func getReleaseDate(addSeparator: Bool = true) -> String {

        if let date = release_date?.dropLast(6) {
            return date + (addSeparator ? " - " : "")
        } else if let date = first_air_date?.dropLast(6) {
            return date + (addSeparator ? " - " : "")
        } else {
            return ""
        }
    }

    /// Stub initialiser for deeplink targets — TMDB id + media_type are
    /// all we have from a notification's userInfo. All other fields are
    /// nil, which is fine because `ContentDetailsView` re-fetches every
    /// field from the API on appear.
    static func stub(id: Int, mediaType: String) -> Result {
        Result(
            backdrop_path: nil,
            first_air_date: nil,
            genre_ids: nil,
            id: id,
            original_title: nil,
            name: nil,
            origin_country: nil,
            original_language: nil,
            original_name: nil,
            overview: nil,
            popularity: nil,
            poster_path: nil,
            release_date: nil,
            title: nil,
            video: nil,
            vote_average: nil,
            vote_count: nil,
            media_type: mediaType,
            profile_path: nil,
            castID: nil,
            runtime: nil,
            known_for: nil
        )
    }

    /// Parses `release_date` (movies) or `first_air_date` (TV) into a `Date`.
    /// Returns nil when neither field is present or fails to parse.
    func releaseDate() -> Date? {
        let raw = release_date ?? first_air_date ?? ""
        guard !raw.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .iso8601)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: raw)
    }
}
