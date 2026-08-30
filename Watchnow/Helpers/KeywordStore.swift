//
//  KeywordStore.swift
//  Watchnow
//
//  Local cache of TMDB keywords ("time travel", "dystopia", …) per title,
//  plus the two derived reads Movie Coach cares about: a title's thematic
//  keywords with the production noise stripped, and the themes that recur
//  across the user's watchlist.
//
//  Keywords barely change after release, so entries live for 30 days and
//  are refreshed in the background by `KeywordEnricher`. Reads deliberately
//  serve expired entries — a stale theme signal still beats no signal —
//  and expiry only decides whether the enricher re-fetches. Device-local by
//  design: like `MovieCoachCache`, this is derived taste context, so it is
//  deliberately not in `CloudSync.syncedKeys`.
//

import Foundation

@MainActor
enum KeywordStore {

    /// Entries older than this are re-fetched by the enricher.
    static let maxAge: TimeInterval = 30 * 24 * 3600

    /// Keeps the UserDefaults blob bounded; oldest fetches are evicted
    /// first. Generous compared to `MovieCoachCache` because evicting a
    /// watchlist title just makes the enricher re-fetch it next launch.
    private static let maxEntries = 400

    /// Keywords kept per title. TMDB can attach 30+, but the thematic value
    /// is concentrated well before that and the model only ever sees a few.
    private static let maxKeywordsPerTitle = 20

    private struct Entry: Codable {
        /// Raw TMDB keyword names, unfiltered — filtering happens on read so
        /// the noise rules can evolve without invalidating the cache.
        let keywords: [String]
        let fetchedAt: Double
    }

    @UserDefault("keywordCache", defaultValue: [:])
    private static var entries: [String: Entry]

    static func key(type: ScreenTypes, id: Int) -> String {
        "\(type.rawValue).\(id)"
    }

    // MARK: - Reads

    /// Cached keyword names for a title, including expired entries. Nil only
    /// when the title has never been fetched successfully.
    static func keywords(type: ScreenTypes, id: Int) -> [String]? {
        entries[key(type: type, id: id)]?.keywords
    }

    /// Whether the entry exists and is younger than `maxAge` — i.e. whether
    /// the enricher can skip this title.
    static func isFresh(type: ScreenTypes, id: Int) -> Bool {
        guard let entry = entries[key(type: type, id: id)] else { return false }
        return Date().timeIntervalSince1970 - entry.fetchedAt < maxAge
    }

    /// Keys of every fresh entry. Lets the enricher scan a large watchlist
    /// against one decoded snapshot instead of decoding the whole cache once
    /// per title.
    static func freshKeys() -> Set<String> {
        let now = Date().timeIntervalSince1970
        return Set(entries.filter { now - $0.value.fetchedAt < maxAge }.keys)
    }

    // MARK: - Writes

    /// Store freshly fetched names. Call only on a successful fetch — an
    /// empty array is a valid result (plenty of titles have no keywords)
    /// and caching it is what prevents a re-fetch on every launch, whereas
    /// a failure should leave any older entry in place.
    static func store(_ names: [String], type: ScreenTypes, id: Int) {
        var store = entries
        store[key(type: type, id: id)] = Entry(
            keywords: Array(names.prefix(maxKeywordsPerTitle)),
            fetchedAt: Date().timeIntervalSince1970
        )

        if store.count > maxEntries {
            let survivors = store.sorted { $0.value.fetchedAt > $1.value.fetchedAt }
                .prefix(maxEntries)
            store = Dictionary(uniqueKeysWithValues: survivors.map { ($0.key, $0.value) })
        }
        entries = store
    }

    // MARK: - Noise filtering

    /// Production metadata that says nothing about what the story feels
    /// like. A short list of exact offenders plus a couple of pattern rules
    /// below — deliberately not a taxonomy.
    private static let noiseKeywords: Set<String> = [
        "sequel", "prequel", "remake", "reboot", "spin off", "spinoff",
        "independent film", "low budget", "b movie", "short film",
        "aftercreditsstinger", "duringcreditsstinger", "post credits scene",
        "anthology", "live action"
    ]

    /// "based on novel or book", "based on comic", "based on video game"…
    /// none of it describes the story itself.
    private static let noisePrefixes = ["based on", "adapted from"]

    /// Catches "woman director", "female director", "directorial debut" and
    /// similar credits trivia in one rule.
    private static let noiseFragments = ["director", "cinema", "filmmaking"]

    /// Keeps only keywords that carry thematic signal, normalised to
    /// lowercase so title themes and user themes compare cleanly.
    static func thematic(_ names: [String]) -> [String] {
        names.compactMap { raw in
            let name = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= 40 else { return nil }
            guard !noiseKeywords.contains(name) else { return nil }
            guard !noisePrefixes.contains(where: name.hasPrefix) else { return nil }
            guard !noiseFragments.contains(where: name.contains) else { return nil }
            return name
        }
    }

    // MARK: - User themes

    /// Themes that keep recurring across the user's saved titles.
    ///
    /// Deterministic and deliberately conservative: a keyword must appear in
    /// at least two *distinct* saved titles before it counts as a theme —
    /// one occurrence is a coincidence, agreement is taste. Occurrences in
    /// recently saved titles score a little extra so the ranking follows
    /// where the user's interest is moving, but recency alone can never
    /// lift a single-title keyword over the bar.
    ///
    /// Works with whatever the cache holds right now: while the background
    /// enrichment is still catching up this simply returns fewer (or no)
    /// themes, and Coach falls back to its genre-based signals.
    static func recurringThemes(in watchlist: [Result], limit: Int = 8) -> [String] {
        let cache = entries          // one decode for the whole scan
        let recencyWindow: TimeInterval = 60 * 24 * 3600

        var titleCount: [String: Int] = [:]
        var score: [String: Double] = [:]

        for item in watchlist {
            guard let id = item.id,
                  let entry = cache[key(type: item.inferredScreenType, id: id)]
            else { continue }

            let weight: Double = {
                guard let added = WatchlistManager.addedDate(forID: id) else { return 1 }
                return Date().timeIntervalSince(added) < recencyWindow ? 1.5 : 1
            }()

            for name in Set(thematic(entry.keywords)) {
                titleCount[name, default: 0] += 1
                score[name, default: 0] += weight
            }
        }

        return titleCount
            .filter { $0.value >= 2 }
            .keys
            .sorted {
                let a = score[$0] ?? 0
                let b = score[$1] ?? 0
                return a == b ? $0 < $1 : a > b
            }
            .prefix(limit)
            .map { $0 }
    }
}

extension Result {
    /// Best-effort media kind for keyword lookups and fetches. Watchlist
    /// items saved by older versions can lack `media_type`; a title with a
    /// `name` but no `title` is a series — the same inference
    /// `MovieCoachContext` uses when checking watchlist membership.
    var inferredScreenType: ScreenTypes {
        if media_type == "tv" { return .tv }
        if media_type == nil, title == nil, name != nil { return .tv }
        return .movie
    }
}
