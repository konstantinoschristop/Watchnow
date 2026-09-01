//
//  MovieCoachContext.swift
//  Watchnow
//
//  Deterministic fact-gathering for Movie Coach.
//
//  The on-device model is only allowed to *synthesise* — never to recall.
//  Everything it is told about a title or about the user is assembled here
//  from data WatchNow already holds (the details screen's TMDB payload plus
//  the local watchlist / folders / reminders / service prefs), and anything
//  we don't actually know is simply omitted from the prompt rather than
//  sent as "unknown". That's what keeps the output honest.
//
//  Nothing here touches the network: the details screen has already fetched
//  every field this uses (including the title's keywords), and the user's
//  recurring themes come from whatever `KeywordEnricher` has cached so far.
//

import Foundation

struct MovieCoachContext {

    // MARK: Title facts

    /// TMDB id — used only as the cache key, never shown to the model.
    let tmdbID: Int
    let title: String
    /// "movie" or "series" — drives the wording the model should use.
    let kind: String
    let year: String?
    let genres: [String]
    /// TMDB genre ids, kept so an explicit like can feed the taste profile.
    let genreIDs: [Int]
    let runtimeMinutes: Int?
    let seasonCount: Int?
    let episodeCount: Int?
    let status: String?
    let rating: Double?
    let voteCount: Int?
    let tagline: String?
    let overview: String?
    let topCast: [String]
    let creators: [String]
    let collectionName: String?
    let isUnreleased: Bool
    let releaseDateText: String?
    /// Subscription services carrying it in the user's region.
    let providers: [String]
    /// This title's thematic TMDB keywords ("time travel", "dystopia"),
    /// noise-filtered and capped — what the story is *about*, beyond genre.
    let titleThemes: [String]

    // MARK: User signals

    let isInWatchlist: Bool
    /// e.g. "8 months" — nil when we never recorded a save date.
    let savedAgo: String?
    let folderName: String?
    let hasReminder: Bool
    let watchlistSize: Int
    /// The user's most-saved genres overall.
    let topUserGenres: [String]
    /// This title's genres that the user demonstrably saves a lot of.
    let genreOverlap: [String]
    /// Themes recurring across the user's saved titles (each appears in at
    /// least two of them) — inferred from cached TMDB keywords.
    let userThemes: [String]
    /// This title's themes that also recur in the watchlist — the sharpest
    /// "why *you*, why *this*" signal Coach has.
    let themeOverlap: [String]
    /// Similar titles already sitting in the user's watchlist.
    let similarSaved: [String]
    /// Services the user says they have that also carry this title.
    let matchedProviders: [String]
    /// Coarse "when are they asking" bucket — weekend vs weeknight.
    let dayContext: String

    // MARK: Fit signals

    /// 0…1 — share of the user's saved-genre weight that this title's genres
    /// account for. 0 means nothing about it resembles what they save.
    let genreAffinity: Double
    /// This title's original language (e.g. "en", "ml").
    let originalLanguage: String?
    /// Languages that actually appear in their watchlist.
    let userLanguages: Set<String>
    /// False for shorts / featurettes / making-ofs — things that aren't a
    /// viewing choice in the sense Coach is being asked about.
    let isFeatureLength: Bool
    /// How many titles the user likes recommend this one (TMDB's own
    /// collaborative filtering). 2+ is a strong endorsement.
    let recommendationHits: Int
    /// They tapped "More like this" on this exact title.
    let isExplicitlyLiked: Bool

    // MARK: - Build

    /// Assemble the context from what the details screen already has.
    /// Every argument is optional-tolerant; missing data just narrows the
    /// facts the model gets.
    @MainActor
    static func build(result: Result,
                      screenType: ScreenTypes,
                      details: ResultDetailsResponse?,
                      cast: [Cast],
                      similars: [Result],
                      providerResults: ProviderResults?,
                      keywords: [String]) -> MovieCoachContext {

        let isSeries = (screenType == .tv)
        let watchlist = WatchlistManager.watchlist
        let titleID = result.id

        // --- Title facts -------------------------------------------------
        let genreNames = (details?.genres ?? []).compactMap(\.name)
        let releaseRaw = details?.release_date ?? details?.first_air_date
        let releaseDate = Self.parseDate(releaseRaw)
        let unreleased = releaseDate.map { $0 > Date() } ?? false

        let flatrate = (providerResults?.flatrate ?? []).compactMap(\.providerName)

        // --- User signals ------------------------------------------------
        // Recompute membership rather than trusting the passed-in flag.
        // `Result`'s `==` compares TMDB ids only, but movie and TV ids are
        // separate namespaces — so a movie can collide with a saved series
        // and Coach would confidently tell the user they'd saved something
        // they hadn't. Match the media type too.
        let reallySaved: Bool = {
            guard let titleID else { return false }
            return watchlist.contains { saved in
                guard saved.id == titleID else { return false }
                let savedIsSeries = saved.media_type == "tv"
                    || (saved.media_type == nil && saved.title == nil && saved.name != nil)
                return savedIsSeries == isSeries
            }
        }()

        let savedAgo: String? = titleID
            .flatMap { WatchlistManager.addedDate(forID: $0) }
            .map { Self.approximateDuration(since: $0) }

        let folderName: String? = titleID
            .flatMap { FolderManager.shared.folderID(for: $0) }
            .flatMap { id in FolderManager.shared.folders.first(where: { $0.id == id })?.name }

        let hasReminder = titleID.map {
            ReminderManager.isScheduled(identifier: ReminderManager.titleIdentifier(resultID: $0))
        } ?? false

        // Compare through a normaliser: the watchlist profile is built from
        // `tmdbGenreNames` (short forms like "Sci-Fi") while the title's own
        // genres come from the details endpoint ("Science Fiction"), so a
        // literal string match would almost never line up.
        let userGenres = Self.topGenres(in: watchlist)
        let normalizedUserGenres = Set(userGenres.map(Self.normalizedGenre))
        let overlap = genreNames.filter { normalizedUserGenres.contains(Self.normalizedGenre($0)) }

        let savedIDs = Set(watchlist.compactMap(\.id))
        let similarSaved = similars
            .filter { $0.id.map(savedIDs.contains) ?? false }
            .prefix(2)
            .map { $0.getResultTitle() }

        let userProviderNames = Set(
            (providerResults?.flatrate ?? [])
                .filter { $0.providerID.map(StreamingPreferences.providerIDs.contains) ?? false }
                .compactMap(\.providerName)
        )

        // --- Themes ------------------------------------------------------
        // The title's keywords were fetched (or served from cache) by the
        // details screen; the user's side is inferred from whatever the
        // background enrichment has cached so far. Both are already
        // lowercase-normalised, so overlap is a straight set intersection.
        let titleThemes = Array(KeywordStore.thematic(keywords).prefix(8))
        let userThemes = KeywordStore.recurringThemes(in: watchlist)
        let themeOverlap = titleThemes.filter(Set(userThemes).contains)

        return MovieCoachContext(
            tmdbID: titleID ?? -1,
            title: result.getResultTitle(),
            kind: isSeries ? "series" : "movie",
            year: Self.nonEmpty(details?.getReleaseDate(addSeparator: false)),
            genres: genreNames,
            genreIDs: (details?.genres ?? []).compactMap(\.id),
            runtimeMinutes: (details?.runtime).flatMap { $0 > 0 ? $0 : nil },
            seasonCount: isSeries ? details?.number_of_seasons : nil,
            episodeCount: isSeries ? details?.number_of_episodes : nil,
            status: Self.nonEmpty(details?.status),
            rating: (details?.vote_average).flatMap { $0 > 0 ? $0 : nil },
            voteCount: details?.vote_count,
            tagline: Self.nonEmpty(details?.tagline),
            overview: Self.nonEmpty(details?.overview),
            topCast: cast.prefix(4).compactMap(\.name),
            creators: (details?.created_by ?? []).compactMap(\.name),
            collectionName: Self.nonEmpty(details?.belongs_to_collection?.name),
            isUnreleased: unreleased,
            releaseDateText: unreleased ? Self.nonEmpty(details?.getDate()) ?? releaseRaw : nil,
            providers: flatrate,
            titleThemes: titleThemes,
            isInWatchlist: reallySaved,
            savedAgo: savedAgo,
            folderName: folderName,
            hasReminder: hasReminder,
            watchlistSize: watchlist.count,
            topUserGenres: userGenres,
            genreOverlap: overlap,
            userThemes: userThemes,
            themeOverlap: themeOverlap,
            similarSaved: Array(similarSaved),
            matchedProviders: Array(userProviderNames),
            dayContext: Self.dayContext(),
            genreAffinity: Self.affinity(of: genreNames, in: watchlist),
            originalLanguage: Self.nonEmpty(result.original_language),
            userLanguages: Set(watchlist.compactMap(\.original_language)),
            // TV always counts; a "movie" under 40 minutes is a short or a
            // behind-the-scenes piece, not a feature.
            isFeatureLength: isSeries || (details?.runtime ?? 0) >= 40,
            recommendationHits: TasteProfile.recommendationHits(for: titleID),
            isExplicitlyLiked: TasteProfile.isLiked(titleID)
        )
    }

    // MARK: - Prompt rendering

    /// The facts block handed to the model. Unknown values are left out
    /// entirely — the model is instructed to use only what appears here, so
    /// an absent line means "don't talk about it".
    var promptText: String {
        var lines: [String] = []

        lines.append("TITLE: \(title) (\(kind))")
        if let year { lines.append("YEAR: \(year)") }
        if !genres.isEmpty { lines.append("GENRES: \(genres.joined(separator: ", "))") }
        if !titleThemes.isEmpty { lines.append("THEMES: \(titleThemes.joined(separator: ", "))") }
        if let runtimeMinutes { lines.append("RUNTIME_MINUTES: \(runtimeMinutes)") }
        if let seasonCount { lines.append("SEASONS: \(seasonCount)") }
        if let episodeCount { lines.append("EPISODES: \(episodeCount)") }
        if let status { lines.append("STATUS: \(status)") }
        if let rating, let voteCount {
            lines.append("AUDIENCE_RATING: \(String(format: "%.1f", rating))/10 from \(voteCount) votes")
        } else if let rating {
            lines.append("AUDIENCE_RATING: \(String(format: "%.1f", rating))/10")
        }
        if let tagline { lines.append("TAGLINE: \(tagline)") }
        if let overview { lines.append("SYNOPSIS: \(overview)") }
        if !topCast.isEmpty { lines.append("CAST: \(topCast.joined(separator: ", "))") }
        if !creators.isEmpty { lines.append("CREATED_BY: \(creators.joined(separator: ", "))") }
        if let collectionName { lines.append("PART_OF: \(collectionName)") }
        if isUnreleased {
            lines.append("NOT_RELEASED_YET: true")
            if let releaseDateText { lines.append("RELEASES_ON: \(releaseDateText)") }
        }
        if !providers.isEmpty {
            lines.append("STREAMING_ON: \(providers.joined(separator: ", "))")
        }

        lines.append("---")
        // Positive facts only. A negative line ("saved: no") is an invitation
        // for the model to flip the negation and tell the user they saved
        // something they didn't — so absence means false, and the
        // instructions say so explicitly.
        lines.append("USER_CONTEXT (only true statements are listed):")
        if isInWatchlist { lines.append("- The user has this saved in their watchlist") }
        if let savedAgo, isInWatchlist { lines.append("- They saved it about \(savedAgo) ago") }
        if let folderName { lines.append("- Filed under the user's \"\(folderName)\" folder") }
        if hasReminder { lines.append("- The user set a release reminder for this") }
        if !topUserGenres.isEmpty {
            lines.append("- Genres the user saves most: \(topUserGenres.joined(separator: ", "))")
        }
        if !genreOverlap.isEmpty {
            lines.append("- This title overlaps those favourites: \(genreOverlap.joined(separator: ", "))")
        }
        if !userThemes.isEmpty {
            lines.append("- Themes that keep recurring across their saved titles: \(userThemes.joined(separator: ", "))")
        }
        if !themeOverlap.isEmpty {
            lines.append("- This title hits themes they keep saving: \(themeOverlap.joined(separator: ", "))")
        }
        if !similarSaved.isEmpty {
            lines.append("- Similar titles already in their watchlist: \(similarSaved.joined(separator: ", "))")
        }
        if !matchedProviders.isEmpty {
            lines.append("- They subscribe to: \(matchedProviders.joined(separator: ", ")) (so they can watch it now)")
        }
        lines.append("- It is currently a \(dayContext)")

        return lines.joined(separator: "\n")
    }

    // MARK: - Verdict

    /// The verdict and the concrete reason for it.
    struct VerdictCall {
        let verdict: MovieCoachVerdict
        /// Plain-language justification, handed to the model so its wording
        /// stays anchored to the same reasoning.
        let reason: String
    }

    /// Decided in code, not by the model.
    ///
    /// When the model was asked to choose the bucket itself it parked on the
    /// most agreeable one ("worth a watch") for essentially everything, which
    /// makes the verdict worthless. The signals that actually determine
    /// whether something suits the user tonight — released or not, runtime,
    /// season count, rating, genre overlap, what they subscribe to — are all
    /// known here, so the choice is deterministic, explainable and varies the
    /// way a real recommendation should. The model's job is the sentence.
    var verdictCall: VerdictCall {

        // ---- Hard disqualifiers -----------------------------------------
        // These are things no amount of "but it's well rated" should rescue.

        if isUnreleased {
            return VerdictCall(verdict: .notIdealRightNow,
                               reason: "it hasn't been released yet, so it can't be watched tonight")
        }

        // Shorts, featurettes, making-ofs. Not a viewing choice.
        if !isFeatureLength {
            return VerdictCall(verdict: .notIdealRightNow,
                               reason: "at only \(runtimeMinutes ?? 0) minutes this is a short extra rather than a feature")
        }

        // Too few ratings to mean anything. A 7.5 from a dozen people is not
        // evidence — this is what let obscure titles pose as well reviewed.
        let credible = (voteCount ?? 0) >= 150
        if !credible {
            return VerdictCall(verdict: .notIdealRightNow,
                               reason: "almost nobody has rated it, so there's no real signal that it's worth the evening")
        }

        // ---- Strongest signals first -------------------------------------

        // They pressed "More like this" on this very title.
        if isExplicitlyLiked {
            return VerdictCall(verdict: .greatPick,
                               reason: "they've told us this is exactly their kind of thing")
        }

        // Several titles they like point at this one. TMDB's collaborative
        // filtering is a much better predictor than genre overlap.
        if recommendationHits >= 2 {
            var why = "it keeps coming up alongside the things they already like"
            if !matchedProviders.isEmpty {
                why += ", and it's on \(matchedProviders.joined(separator: " or "))"
            }
            return VerdictCall(verdict: .greatPick, reason: why)
        }

        // ---- Explicit interest beats everything else ---------------------
        // They already chose this. The question isn't "does it fit their
        // taste" — it's "is tonight the night". Never demote a saved title
        // just because it's long; they knowingly signed up for it.
        let alreadyWants = isInWatchlist || hasReminder
        if alreadyWants {
            if dayContext == "weeknight", (runtimeMinutes ?? 0) >= 165 {
                return VerdictCall(verdict: .maybeLater,
                                   reason: "they already want to see it, but it's a very long sitting for a weeknight")
            }
            var why = "it's already on their list"
            if !matchedProviders.isEmpty {
                why += " and they can start it right now on \(matchedProviders.joined(separator: " or "))"
            }
            return VerdictCall(verdict: .greatPick, reason: why)
        }

        // ---- Taste fit ----------------------------------------------------
        // Two shared recurring themes is as strong as genre affinity: the
        // user demonstrably keeps saving stories about exactly this.
        let stronglyFits = genreAffinity >= 0.30 || !similarSaved.isEmpty
            || recommendationHits >= 1 || themeOverlap.count >= 2
        let looselyFits  = genreAffinity >= 0.12 || !themeOverlap.isEmpty
        let wellRated    = (rating ?? 0) >= 7.0

        // Actively wrong for this user: nothing they save looks like this.
        // A shared theme rescues a genre mismatch — a space documentary can
        // still land with someone whose watchlist is full of space fiction.
        if genreAffinity <= 0.02, similarSaved.isEmpty, themeOverlap.isEmpty {
            let genreText = genres.isEmpty ? "this kind of thing" : genres.prefix(2).joined(separator: "/")
            return VerdictCall(verdict: .notIdealRightNow,
                               reason: "\(genreText) is nothing like what they actually save, however it's rated")
        }

        // A language they never watch, with nothing else pulling for it.
        if let originalLanguage, !userLanguages.isEmpty,
           !userLanguages.contains(originalLanguage), !stronglyFits {
            return VerdictCall(verdict: .notIdealRightNow,
                               reason: "it's outside the languages they normally watch and doesn't otherwise match their taste")
        }

        // Genuinely strong fit. Shared themes are the sharpest thing Coach
        // can say — "you keep saving time-travel mysteries and this is one"
        // beats a genre match — so they lead the reason when present.
        if stronglyFits, wellRated {
            var why = "it's well rated"
            if !themeOverlap.isEmpty {
                why += " and leans into \(themeOverlap.prefix(2).joined(separator: " and ")) — themes they keep saving"
            } else if !genreOverlap.isEmpty {
                why += " and sits right in the \(genreOverlap.prefix(2).joined(separator: " / ")) territory they keep saving"
            } else if !similarSaved.isEmpty {
                why += " and is close to \(similarSaved.joined(separator: " and ")), already on their list"
            }
            if !matchedProviders.isEmpty {
                why += ", and they can start it now on \(matchedProviders.joined(separator: " or "))"
            }
            return VerdictCall(verdict: .greatPick, reason: why)
        }

        // Fits their taste but isn't especially well regarded.
        if stronglyFits {
            return VerdictCall(verdict: .goodPick,
                               reason: "it's the kind of thing they go for, even if reviews are only middling")
        }

        // Only a loose connection — hedge rather than endorse.
        if looselyFits, wellRated {
            return VerdictCall(verdict: .goodPick,
                               reason: "it's well regarded and shares some ground with what they save, without being a bullseye")
        }

        return VerdictCall(verdict: .maybeLater,
                           reason: "there's not much here that lines up with what they usually watch")
    }

    /// True when there's enough personal signal to justify a personalised
    /// answer. Below this bar the model is told to give a title-only take
    /// rather than pretend it knows the user.
    var hasMeaningfulPersonalSignal: Bool {
        isInWatchlist || hasReminder || !genreOverlap.isEmpty
            || !similarSaved.isEmpty || !matchedProviders.isEmpty
            || !themeOverlap.isEmpty
    }

    // MARK: - Cache signature

    /// Stable fingerprint of everything that should invalidate a cached
    /// answer. Uses FNV-1a rather than `Hashable` because Swift's hashing is
    /// randomly seeded per process and would never match across launches.
    var signature: String {
        let parts: [String] = [
            title, kind, status ?? "", String(runtimeMinutes ?? -1),
            String(seasonCount ?? -1), String(episodeCount ?? -1),
            genres.joined(separator: ","),
            providers.sorted().joined(separator: ","),
            isInWatchlist ? "wl1" : "wl0",
            // Crossing the "enough history" threshold, or the profile
            // growing, should produce a fresh read.
            String(watchlistSize),
            savedAgo ?? "",
            folderName ?? "",
            hasReminder ? "rm1" : "rm0",
            topUserGenres.joined(separator: ","),
            genreOverlap.joined(separator: ","),
            // This title's own themes belong in the signature: they change
            // only when its keywords first land, and they change what Coach
            // can say about it.
            titleThemes.joined(separator: ","),
            // The user's themes are deliberately reduced to a sorted top
            // few. In full they are a ranking over the *whole* watchlist, so
            // every keyword the background enrichment fetched — for any
            // title — reshuffled the tail and invalidated every cached
            // answer in the app, over and over, for the whole first run.
            // The leading themes are what actually reaches the prompt, and
            // sorting drops the recency reshuffles that don't.
            userThemes.prefix(4).sorted().joined(separator: ","),
            similarSaved.sorted().joined(separator: ","),
            matchedProviders.sorted().joined(separator: ","),
            dayContext
        ]
        return Self.fnv1a(parts.joined(separator: "|"))
    }

    private static func fnv1a(_ string: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 36)
    }

    // MARK: - Helpers

    /// Reconciles TMDB's full genre names with the short forms in
    /// `tmdbGenreNames`, including the TV-only combined buckets.
    /// Shared with `TasteProfile` so both sides of a comparison agree.
    static func normalizedGenre(_ name: String) -> String {
        switch name {
        case "Science Fiction", "Sci-Fi & Fantasy": return "Sci-Fi"
        case "Action & Adventure":                  return "Action"
        case "War & Politics":                      return "War"
        case "Kids":                                return "Family"
        default:                                    return name
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .iso8601)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: raw)
    }

    /// Coarse, human phrasing ("3 weeks", "8 months") — deliberately fuzzy so
    /// the cache signature doesn't churn daily.
    private static func approximateDuration(since date: Date) -> String {
        let days = max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
        switch days {
        case 0...6:    return "a few days"
        case 7...27:   return "\(max(1, days / 7)) week\(days / 7 == 1 ? "" : "s")"
        case 28...364: let m = max(1, days / 30); return "\(m) month\(m == 1 ? "" : "s")"
        default:       let y = days / 365; return y == 1 ? "a year" : "\(y) years"
        }
    }

    /// Share of the user's total saved-genre weight that `genres` covers.
    /// Uses the *whole* watchlist distribution rather than a top-3 list, so a
    /// title made entirely of genres they never save scores a true zero
    /// instead of merely failing to match.
    @MainActor
    private static func affinity(of genres: [String], in watchlist: [Result]) -> Double {
        var profile: [String: Int] = [:]
        // A save is a mild positive…
        for item in watchlist {
            for id in item.genre_ids ?? [] {
                if let name = tmdbGenreNames[id] {
                    profile[normalizedGenre(name), default: 0] += 1
                }
            }
        }
        // …an explicit "more like this" counts for much more…
        for (name, weight) in TasteProfile.likedGenres {
            profile[name, default: 0] += weight
        }
        // …and a Movie Night pass pulls the genre back down.
        for (name, weight) in TasteProfile.passedGenres {
            profile[name] = max(0, (profile[name] ?? 0) - weight)
        }

        let total = profile.values.reduce(0, +)
        guard total > 0, !genres.isEmpty else { return 0 }
        let matched = genres.reduce(0) { $0 + (profile[normalizedGenre($1)] ?? 0) }
        return min(1.0, Double(matched) / Double(total))
    }

    /// Top 3 genre names across the saved titles, by frequency.
    private static func topGenres(in watchlist: [Result]) -> [String] {
        var counts: [String: Int] = [:]
        for item in watchlist {
            for id in item.genre_ids ?? [] {
                if let name = tmdbGenreNames[id] { counts[name, default: 0] += 1 }
            }
        }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(3)
            .map(\.key)
    }

    private static func dayContext() -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let isWeekend = (weekday == 1 || weekday == 7 || weekday == 6) // Sun, Sat, Fri
        return isWeekend ? "weekend" : "weeknight"
    }
}
