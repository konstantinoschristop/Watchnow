//
//  WhatsNewModel.swift
//  Watchnow
//
//  "While You Were Away" — the value types.
//
//  A `WatchlistChange` is one meaningful, user-facing event on a watchlist
//  title ("new trailer", "now on Netflix"), produced by `ChangeClassifier`
//  from a diff between fresh TMDB state and the locally persisted
//  `WatchlistSnapshot`. Everything here is deterministic and Codable —
//  detection never involves AI, and the copy lives on the types so the
//  SwiftUI views stay logic-free.
//

import Foundation

// MARK: - Change kind

/// The kinds of change Watchnow considers worth telling the user about.
/// Deliberately short — TMDB records dozens of edit types (posters,
/// translations, tagline tweaks…) and everything not listed here is noise
/// by definition.
///
/// Future kinds (leaving streaming, awards, cast announcements, countdown
/// milestones…) slot in by adding a case, a rank, copy, and one classifier
/// rule — nothing else changes.
enum WatchlistChangeKind: String, Codable, CaseIterable {
    case streamingAvailability
    case newTrailer
    case releaseDateChanged
    case newEpisode
    case newSeason
    case released
    case episodeDateChanged

    /// Presentation priority — lower shows first. Streaming leads because
    /// it's the one change the user can act on this minute.
    var rank: Int {
        switch self {
        case .streamingAvailability: return 0
        case .newTrailer:            return 1
        case .releaseDateChanged:    return 2
        case .newEpisode:            return 3
        case .newSeason:             return 4
        case .released:              return 5
        case .episodeDateChanged:    return 6
        }
    }

    /// The short label on the card ("NEW TRAILER").
    var label: String {
        switch self {
        case .streamingAvailability: return "Now streaming"
        case .newTrailer:            return "New trailer"
        case .releaseDateChanged:    return "Release date updated"
        case .newEpisode:            return "New episode"
        case .newSeason:             return "New season"
        case .released:              return "Released"
        case .episodeDateChanged:    return "New air date"
        }
    }

    var icon: String {
        switch self {
        case .streamingAvailability: return "play.tv.fill"
        case .newTrailer:            return "video.fill"
        case .releaseDateChanged:    return "calendar"
        case .newEpisode:            return "sparkles.tv.fill"
        case .newSeason:             return "square.stack.fill"
        case .released:              return "popcorn.fill"
        case .episodeDateChanged:    return "clock.fill"
        }
    }
}

// MARK: - Metadata

/// Only what the UI needs to render the card — never a raw TMDB payload.
/// Flat optionals rather than per-kind shapes, matching how the rest of
/// the app models sparse TMDB data.
struct ChangeMetadata: Codable, Equatable {
    var videoKey: String?
    var videoName: String?
    var oldDate: String?
    var newDate: String?
    var providerName: String?
    var seasonNumber: Int?
    var episodeNumber: Int?
    var episodeName: String?
    var airDate: String?

    init(videoKey: String? = nil, videoName: String? = nil,
         oldDate: String? = nil, newDate: String? = nil,
         providerName: String? = nil,
         seasonNumber: Int? = nil, episodeNumber: Int? = nil,
         episodeName: String? = nil, airDate: String? = nil) {
        self.videoKey = videoKey
        self.videoName = videoName
        self.oldDate = oldDate
        self.newDate = newDate
        self.providerName = providerName
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.episodeName = episodeName
        self.airDate = airDate
    }
}

// MARK: - Change

/// One meaningful event on a watchlist title.
struct WatchlistChange: Codable, Equatable, Identifiable {

    /// Stable across syncs (built from the change's own facts, not a UUID),
    /// so "seen" tracking survives re-detection.
    let id: String
    let mediaID: Int
    /// "movie" | "tv" — same convention as the rest of the app's keys.
    let mediaType: String
    let kind: WatchlistChangeKind
    let title: String
    let posterPath: String?
    /// Wide artwork for the briefing's hero treatments; nil falls back to
    /// the poster (blurred) and then to a plain gradient.
    let backdropPath: String?
    /// Epoch seconds of detection.
    let occurredAt: Double
    let metadata: ChangeMetadata
    /// The user explicitly set a release reminder for this title — ranks
    /// above everything else.
    let hasReminder: Bool

    var priority: Int { kind.rank }

    var posterURL: URL? {
        posterPath.flatMap { URL(string: API.Common.imageUrl(imageId: $0)) }
    }

    var backdropURL: URL? {
        backdropPath.flatMap { URL(string: API.Common.imageUrl(imageId: $0)) }
    }

    var screenType: ScreenTypes { mediaType == "tv" ? .tv : .movie }

    var deepLink: DeepLink {
        DeepLink(id: mediaID, mediaType: mediaType == "tv" ? .tv : .movie)
    }

    /// YouTube URL when this is a trailer change the user can watch in-app.
    var trailerURL: URL? {
        guard kind == .newTrailer, let key = metadata.videoKey else { return nil }
        return URL(string: API.Common.youtubeUrl(videoId: key))
    }

    /// The one-line sentence under the label. Plain human copy — never
    /// mentions TMDB or field names.
    var detailText: String {
        switch kind {
        case .streamingAvailability:
            if let provider = metadata.providerName {
                return "Now available on \(provider)."
            }
            return "Now available to stream."
        case .newTrailer:
            return "A new trailer was added."
        case .releaseDateChanged:
            if let pretty = Self.prettyDate(metadata.newDate) {
                return metadata.oldDate == nil
                    ? "Coming \(pretty)."
                    : "Now coming \(pretty)."
            }
            return "The release date was updated."
        case .newEpisode:
            if let season = metadata.seasonNumber, let episode = metadata.episodeNumber {
                return "Season \(season), Episode \(episode) is now available."
            }
            return "A new episode is available."
        case .newSeason:
            if let season = metadata.seasonNumber {
                return "Season \(season) is on the way."
            }
            return "A new season is on the way."
        case .released:
            return "It's officially out now."
        case .episodeDateChanged:
            if let season = metadata.seasonNumber, let episode = metadata.episodeNumber,
               let pretty = Self.prettyDate(metadata.airDate) {
                return "Season \(season), Episode \(episode) now airs \(pretty)."
            }
            if let pretty = Self.prettyDate(metadata.airDate) {
                return "The next episode now airs \(pretty)."
            }
            return "The next episode's air date changed."
        }
    }

    /// Stable identity from the change's own facts. `detail` disambiguates
    /// repeats of the same kind (a second new trailer is a new event).
    static func makeID(mediaType: String, mediaID: Int,
                       kind: WatchlistChangeKind, detail: String) -> String {
        "\(mediaType).\(mediaID).\(kind.rawValue).\(detail)"
    }

    /// "2026-12-18" → "December 18, 2026".
    static func prettyDate(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .iso8601)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: raw) else { return nil }
        let printer = DateFormatter()
        printer.dateStyle = .long
        printer.timeStyle = .none
        return printer.string(from: date)
    }
}

// MARK: - Snapshot

/// The locally persisted state of one watchlist title — just enough to
/// tell whether something meaningful changed since we last looked, never
/// a stored TMDB payload.
struct WatchlistSnapshot: Codable, Equatable {

    let mediaID: Int
    /// "movie" | "tv".
    let mediaType: String
    var title: String
    var posterPath: String?
    // Optional so snapshots persisted before this field existed keep
    // decoding (decodeIfPresent → nil).
    var backdropPath: String?
    /// Movie release date / TV first-air date (yyyy-MM-dd).
    var releaseDate: String?
    var status: String?
    var seasonCount: Int?
    var episodeCount: Int?
    /// `last_episode_to_air.id` — rolls forward when a new episode airs.
    var lastEpisodeID: Int?
    var nextEpisodeID: Int?
    var nextEpisodeAirDate: String?
    /// TMDB ids of the trailers/teasers known at last check.
    var videoIDs: [String]
    /// Flatrate (subscription) provider ids in the user's region.
    var providerIDs: [Int]
    /// Epoch seconds of the last successful check.
    var lastCheckedAt: Double

    var key: String { "\(mediaType).\(mediaID)" }

    static func key(mediaType: String, mediaID: Int) -> String {
        "\(mediaType).\(mediaID)"
    }
}
