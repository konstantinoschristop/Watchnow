//
//  ChangeClassifier.swift
//  Watchnow
//
//  The judgement layer of What's New: given a title's persisted snapshot
//  and whatever fresh TMDB state the monitor fetched, decide which changes
//  are worth a user's attention — and which are noise.
//
//  Everything here is a pure function of its inputs (no network, no
//  singletons, explicit `now`), which is what makes the whole feature unit
//  testable. The bias is conservative throughout: posters, overviews,
//  translations and metadata corrections never produce a change, an old
//  film's release-date correction is ignored, and when in doubt nothing is
//  surfaced. A briefing that's occasionally quiet beats one that cried wolf.
//

import Foundation

enum ChangeClassifier {

    /// What the monitor managed to fetch this round. Any nil domain simply
    /// isn't diffed — a failed request can never masquerade as a change.
    struct Fresh {
        var details: ResultDetailsResponse?
        var videos: [VideoModelResult]?
        /// Flatrate provider ids in the user's region; nil = not fetched.
        var providerIDs: [Int]?
        /// provider id → display name, for the card copy.
        var providerNames: [Int: String] = [:]
        /// The region's raw availability, kept so the watchlist can record
        /// which service a saved title streams on. The monitor already pays
        /// for this request on every saved title, so the badge comes free
        /// rather than waiting for the user to open each one.
        var providerResults: ProviderResults?

        init(details: ResultDetailsResponse? = nil,
             videos: [VideoModelResult]? = nil,
             providerIDs: [Int]? = nil,
             providerNames: [Int: String] = [:],
             providerResults: ProviderResults? = nil) {
            self.details = details
            self.videos = videos
            self.providerIDs = providerIDs
            self.providerNames = providerNames
            self.providerResults = providerResults
        }
    }

    /// A new episode / release only counts as news while it's actually new.
    private static let recencyWindow: TimeInterval = 30 * 24 * 3600

    // MARK: - Detection

    /// Diff fresh state against the snapshot and return every meaningful
    /// change. `subscribedProviderIDs` (the user's own services) only
    /// influences which provider gets named when several appear at once.
    static func changes(from snapshot: WatchlistSnapshot,
                        fresh: Fresh,
                        hasReminder: Bool,
                        subscribedProviderIDs: Set<Int> = [],
                        now: Date = Date()) -> [WatchlistChange] {

        var found: [WatchlistChange] = []

        func add(_ kind: WatchlistChangeKind, detail: String, metadata: ChangeMetadata) {
            found.append(WatchlistChange(
                id: WatchlistChange.makeID(mediaType: snapshot.mediaType,
                                           mediaID: snapshot.mediaID,
                                           kind: kind,
                                           detail: detail),
                mediaID: snapshot.mediaID,
                mediaType: snapshot.mediaType,
                kind: kind,
                title: snapshot.title,
                posterPath: snapshot.posterPath,
                backdropPath: snapshot.backdropPath,
                occurredAt: now.timeIntervalSince1970,
                metadata: metadata,
                hasReminder: hasReminder
            ))
        }

        // --- Streaming availability ---------------------------------------
        // The highest-value change: the user can act on it right now. Only
        // additions are surfaced; a provider disappearing is not actionable.
        if let freshProviders = fresh.providerIDs {
            let added = Set(freshProviders).subtracting(snapshot.providerIDs)
            if let featured = added.sorted(by: { lhs, rhs in
                // Name a service the user actually subscribes to when one
                // of the new homes is theirs.
                let lhsOwned = subscribedProviderIDs.contains(lhs)
                let rhsOwned = subscribedProviderIDs.contains(rhs)
                return lhsOwned == rhsOwned ? lhs < rhs : lhsOwned
            }).first {
                add(.streamingAvailability,
                    detail: String(featured),
                    metadata: ChangeMetadata(providerName: fresh.providerNames[featured]))
            }
        }

        // --- New trailer ---------------------------------------------------
        // One change no matter how many videos landed; full trailers beat
        // teasers, official uploads beat fan-ish ones.
        if let videos = fresh.videos {
            let known = Set(snapshot.videoIDs)
            let new = trailers(in: videos).filter { video in
                guard let id = video.id else { return false }
                return !known.contains(id)
            }
            let best = new.sorted { lhs, rhs in
                let lhsTrailer = (lhs.type == "Trailer"), rhsTrailer = (rhs.type == "Trailer")
                if lhsTrailer != rhsTrailer { return lhsTrailer }
                return (lhs.official ?? false) && !(rhs.official ?? false)
            }.first
            if let best, let id = best.id {
                add(.newTrailer,
                    detail: id,
                    metadata: ChangeMetadata(videoKey: best.key, videoName: best.name))
            }
        }

        if let details = fresh.details {
            if snapshot.mediaType == "tv" {
                tvChanges(snapshot: snapshot, details: details, now: now, add: add)
            } else {
                movieChanges(snapshot: snapshot, details: details, now: now, add: add)
            }
        }

        return found
    }

    /// Movie-specific diffs, reported through the `add` closure — the split
    /// just keeps `changes` readable.
    private static func movieChanges(snapshot: WatchlistSnapshot,
                                     details: ResultDetailsResponse,
                                     now: Date,
                                     add: (WatchlistChangeKind, String, ChangeMetadata) -> Void) {

        // Release date moved — but only when it touches the future. A date
        // correction on a film from 2009 is an edit, not news.
        if let newDate = nonEmpty(details.release_date),
           newDate != snapshot.releaseDate,
           isFutureOrRecent(newDate, now: now) || isFutureOrRecent(snapshot.releaseDate, now: now) {
            add(.releaseDateChanged, newDate,
                ChangeMetadata(oldDate: snapshot.releaseDate, newDate: newDate))
        }

        // Went from any pre-release status to Released, and recently enough
        // to still be news.
        if details.status == "Released",
           let oldStatus = snapshot.status, oldStatus != "Released",
           isFutureOrRecent(details.release_date ?? snapshot.releaseDate, now: now) {
            add(.released, "released", ChangeMetadata(newDate: details.release_date))
        }
    }

    /// TV-specific diffs.
    private static func tvChanges(snapshot: WatchlistSnapshot,
                                  details: ResultDetailsResponse,
                                  now: Date,
                                  add: (WatchlistChangeKind, String, ChangeMetadata) -> Void) {

        // New episode: the "last aired" pointer rolled forward to an episode
        // that aired recently. Recency matters — a data fix on an old show
        // also moves the pointer, and that's not news.
        if let last = details.last_episode_to_air, let lastID = last.id,
           lastID != snapshot.lastEpisodeID,
           let aired = last.airDateValue(),
           now.timeIntervalSince(aired) < recencyWindow, aired <= now {
            add(.newEpisode, String(lastID),
                ChangeMetadata(seasonNumber: last.season_number,
                               episodeNumber: last.episode_number,
                               episodeName: last.name,
                               airDate: last.air_date))
        }

        // New season appeared in the season list.
        if let freshCount = details.number_of_seasons,
           let knownCount = snapshot.seasonCount,
           freshCount > knownCount {
            add(.newSeason, String(freshCount),
                ChangeMetadata(seasonNumber: freshCount))
        }

        // The already-scheduled next episode moved to a different date.
        if let next = details.next_episode_to_air, let nextID = next.id,
           nextID == snapshot.nextEpisodeID,
           let newAir = nonEmpty(next.air_date),
           let oldAir = snapshot.nextEpisodeAirDate,
           newAir != oldAir {
            add(.episodeDateChanged, "\(nextID).\(newAir)",
                ChangeMetadata(oldDate: oldAir,
                               seasonNumber: next.season_number,
                               episodeNumber: next.episode_number,
                               airDate: newAir))
        }

        // First air date confirmed or moved for an unaired series.
        if let newDate = nonEmpty(details.first_air_date),
           newDate != snapshot.releaseDate,
           snapshot.lastEpisodeID == nil,
           isFutureOrRecent(newDate, now: now) || isFutureOrRecent(snapshot.releaseDate, now: now) {
            add(.releaseDateChanged, newDate,
                ChangeMetadata(oldDate: snapshot.releaseDate, newDate: newDate))
        }
    }

    // MARK: - Ranking

    /// Presentation order: collapse to one change per title (a title with a
    /// new trailer *and* a moved date is one card, led by whichever matters
    /// more), then reminder titles first, then by kind priority, newest
    /// first as the tiebreak.
    static func ranked(_ changes: [WatchlistChange]) -> [WatchlistChange] {
        var bestPerTitle: [String: WatchlistChange] = [:]
        for change in changes {
            let key = "\(change.mediaType).\(change.mediaID)"
            if let current = bestPerTitle[key] {
                if isOrderedBefore(change, current) { bestPerTitle[key] = change }
            } else {
                bestPerTitle[key] = change
            }
        }
        return bestPerTitle.values.sorted(by: isOrderedBefore)
    }

    private static func isOrderedBefore(_ lhs: WatchlistChange, _ rhs: WatchlistChange) -> Bool {
        if lhs.hasReminder != rhs.hasReminder { return lhs.hasReminder }
        if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
        return lhs.id < rhs.id // deterministic tiebreak
    }

    // MARK: - Snapshots

    /// The baseline for a title just entering the system. Establishing it
    /// produces no changes by definition — this is the "current state", not
    /// an event.
    static func makeSnapshot(mediaID: Int,
                             mediaType: String,
                             title: String,
                             posterPath: String?,
                             backdropPath: String?,
                             fresh: Fresh,
                             now: Date = Date()) -> WatchlistSnapshot {
        WatchlistSnapshot(
            mediaID: mediaID,
            mediaType: mediaType,
            title: nonEmpty(fresh.details?.title) ?? nonEmpty(fresh.details?.name) ?? title,
            posterPath: fresh.details?.poster_path ?? posterPath,
            backdropPath: fresh.details?.backdrop_path ?? backdropPath,
            releaseDate: mediaType == "tv"
                ? nonEmpty(fresh.details?.first_air_date)
                : nonEmpty(fresh.details?.release_date),
            status: fresh.details?.status,
            seasonCount: fresh.details?.number_of_seasons,
            episodeCount: fresh.details?.number_of_episodes,
            lastEpisodeID: fresh.details?.last_episode_to_air?.id,
            nextEpisodeID: fresh.details?.next_episode_to_air?.id,
            nextEpisodeAirDate: nonEmpty(fresh.details?.next_episode_to_air?.air_date),
            videoIDs: trailers(in: fresh.videos ?? []).compactMap(\.id),
            providerIDs: fresh.providerIDs ?? [],
            lastCheckedAt: now.timeIntervalSince1970
        )
    }

    /// Roll the snapshot forward after a check, merging in only the domains
    /// that were actually fetched — a failed request never wipes known
    /// state (which would make the same change fire again later).
    static func updatedSnapshot(_ snapshot: WatchlistSnapshot,
                                fresh: Fresh,
                                now: Date = Date()) -> WatchlistSnapshot {
        var next = snapshot
        if let details = fresh.details {
            next.title = nonEmpty(details.title) ?? nonEmpty(details.name) ?? snapshot.title
            next.posterPath = details.poster_path ?? snapshot.posterPath
            next.backdropPath = details.backdrop_path ?? snapshot.backdropPath
            next.releaseDate = snapshot.mediaType == "tv"
                ? (nonEmpty(details.first_air_date) ?? snapshot.releaseDate)
                : (nonEmpty(details.release_date) ?? snapshot.releaseDate)
            next.status = details.status ?? snapshot.status
            next.seasonCount = details.number_of_seasons ?? snapshot.seasonCount
            next.episodeCount = details.number_of_episodes ?? snapshot.episodeCount
            next.lastEpisodeID = details.last_episode_to_air?.id ?? snapshot.lastEpisodeID
            next.nextEpisodeID = details.next_episode_to_air?.id
            next.nextEpisodeAirDate = nonEmpty(details.next_episode_to_air?.air_date)
        }
        if let videos = fresh.videos {
            next.videoIDs = trailers(in: videos).compactMap(\.id)
        }
        if let providers = fresh.providerIDs {
            next.providerIDs = providers
        }
        next.lastCheckedAt = now.timeIntervalSince1970
        return next
    }

    // MARK: - Helpers

    /// The videos worth tracking: trailers and teasers, YouTube-hosted (the
    /// only site the app can play).
    private static func trailers(in videos: [VideoModelResult]) -> [VideoModelResult] {
        videos.filter { video in
            (video.type == "Trailer" || video.type == "Teaser")
                && (video.site == nil || video.site == "YouTube")
        }
    }

    /// Whether a yyyy-MM-dd date is in the future or within the recency
    /// window — the test for "does this date still matter to a person
    /// deciding what to watch".
    private static func isFutureOrRecent(_ raw: String?, now: Date) -> Bool {
        guard let raw, !raw.isEmpty else { return false }
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .iso8601)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: raw) else { return false }
        return date > now.addingTimeInterval(-recencyWindow)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
