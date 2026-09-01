//
//  WatchlistManager.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation

@propertyWrapper
struct UserDefault<T: Codable> {
    let key: String
    let defaultValue: T
    
    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    var wrappedValue: T {
        get {
            if let data = UserDefaults.standard.object(forKey: key) as? Data,
               let user = try? JSONDecoder().decode(T.self, from: data) {
                return user
                
            }
            
            return  defaultValue
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: key)
                // Mirror to iCloud for the keys that sync (watchlist, Movie
                // Night prefs); no-op for everything else.
                CloudSync.pushIfSynced(key)
            }
        }
    }
}

/// The one streaming service remembered for a saved title.
///
/// Stored beside the watchlist rather than inside `Result`, matching how
/// saved dates and folder membership already work: `Result` is decoded from
/// a dozen TMDB endpoints and none of them know about this, so keying a
/// side-table by id keeps the wire type honest.
struct SavedProvider: Codable, Hashable {

    /// How the title is available, so the badge never overstates it.
    enum Kind: String, Codable {
        /// Included with a subscription — open it and watch it.
        case stream
        /// Available, but you pay per title.
        case rent
    }

    let id: Int
    let name: String
    /// TMDB-relative path; render through `API.Common.imageUrl(imageId:)`.
    let logoPath: String?
    /// Optional purely so records written before this field existed keep
    /// decoding — read `availability` instead of this.
    ///
    /// A property default would *not* have been enough: Swift's synthesized
    /// `Decodable` ignores default values and throws `keyNotFound` for a
    /// missing non-optional key. That failure would not have been local
    /// either — `@UserDefault` decodes the whole `[String: SavedProvider]`
    /// dictionary in one go, so a single old record would have thrown the
    /// entire table away and blanked every badge. Same reasoning as
    /// `WatchlistSnapshot.backdropPath`.
    private let kind: Kind?
    /// Epoch seconds. Availability moves constantly — this is what lets a
    /// stale record be recognised rather than trusted forever.
    let capturedAt: Double

    /// How the title is available. Records predating `kind` were
    /// subscription-only by construction, so that is the right default.
    var availability: Kind { kind ?? .stream }

    init(id: Int, name: String, logoPath: String?,
         kind: Kind = .stream,
         capturedAt: Double = Date().timeIntervalSince1970) {
        self.id = id
        self.name = name
        self.logoPath = logoPath
        self.kind = kind
        self.capturedAt = capturedAt
    }

    /// The service worth remembering out of everything TMDB lists for a
    /// region, or nil when there isn't one.
    ///
    /// Subscription first, then rental. An earlier version took subscriptions
    /// only, on the reasoning that "almost everything is rentable" — true, but
    /// it meant most saved titles got no badge at all, which is a worse answer
    /// than a correctly-labelled rental. Notably TMDB files the Apple TV
    /// *storefront* under rent/buy and only Apple TV+ under flatrate, so a
    /// subscription-only rule silently dropped the most common case.
    ///
    /// `kind` carries the distinction so the UI can be honest about which it
    /// is rather than implying everything is included.
    ///
    /// Within a tier, a service the user actually pays for wins — that's the
    /// difference between "this is streaming" and "this is streaming, on
    /// something you have". Otherwise TMDB's own display priority decides.
    static func main(from results: ProviderResults?,
                     subscribedTo owned: Set<Int> = []) -> SavedProvider? {
        if let best = best(of: results?.flatrate, owned: owned) {
            return make(best, kind: .stream)
        }
        // `rent` and `buy` are usually the same storefronts; rent is the
        // cheaper claim of the two, so it's the one worth showing.
        if let best = best(of: results?.rent ?? results?.buy, owned: owned) {
            return make(best, kind: .rent)
        }
        return nil
    }

    private static func best(of entries: [Flatrate]?, owned: Set<Int>) -> Flatrate? {
        (entries ?? [])
            .filter { $0.providerID != nil && $0.providerName != nil }
            .min { lhs, rhs in
                let lhsOwned = owned.contains(lhs.providerID ?? -1)
                let rhsOwned = owned.contains(rhs.providerID ?? -1)
                if lhsOwned != rhsOwned { return lhsOwned }
                let lhsPriority = lhs.displayPriority ?? .max
                let rhsPriority = rhs.displayPriority ?? .max
                if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
                return (lhs.providerID ?? 0) < (rhs.providerID ?? 0)
            }
    }

    private static func make(_ entry: Flatrate, kind: Kind) -> SavedProvider? {
        guard let id = entry.providerID, let name = entry.providerName else { return nil }
        return SavedProvider(id: id, name: name, logoPath: entry.logoPath, kind: kind)
    }
}

@MainActor
enum WatchlistManager {
    
    @UserDefault("watchlist", defaultValue: []) static var watchlist: [Result]

    /// TMDB-id (as String) → when the title was saved (epoch seconds).
    /// Lets Movie Coach say "you saved this a few months ago". Only titles
    /// saved from this version onward have an entry; callers must treat a
    /// missing date as "unknown" rather than "just added".
    @UserDefault("watchlistAddedDates", defaultValue: [:]) static var addedDates: [String: Double]

    /// TMDB id (as String) → the service the title streams on, captured the
    /// last time its details screen was open. Absent means "we don't know",
    /// never "nowhere".
    @UserDefault("watchlistProviders", defaultValue: [:]) static var providers: [String: SavedProvider]

    /// When `id` was added to the watchlist, if we recorded it.
    static func addedDate(forID id: Int) -> Date? {
        guard let epoch = addedDates[String(id)] else { return nil }
        return Date(timeIntervalSince1970: epoch)
    }

    static func provider(forID id: Int) -> SavedProvider? {
        providers[String(id)]
    }

    // MARK: - Refresh from a details fetch

    /// Bring a saved entry up to date with what the details screen just
    /// learned: fresher artwork and facts, and which service it streams on.
    ///
    /// A no-op for anything not saved, so the details screen can call it
    /// unconditionally. Returns whether anything was written, so a caller can
    /// avoid re-publishing a list for nothing.
    ///
    /// Order in the array is untouched and so is the saved date — the entry is
    /// updated in place. A refresh is not a re-save, and it must not move a
    /// title to the top of the list or reset "you saved this months ago".
    @discardableResult
    static func refreshSavedEntry(id: Int,
                                  details: ResultDetailsResponse?,
                                  providerResults: ProviderResults?) -> Bool {
        var didChange = false

        if let details {
            var list = watchlist
            if let index = list.firstIndex(where: { $0.id == id }) {
                var entry = list[index]
                let before = entry
                entry.refresh(from: details)
                // `Result` compares on id alone, so an equality check would
                // always pass here. Compare the encoded form instead: it is
                // the only honest answer to "did any stored field move?".
                if encoded(before) != encoded(entry) {
                    list[index] = entry
                    watchlist = list
                    didChange = true
                }
            }
        }

        // Availability is re-read even when the details fetch failed — the
        // providers call is independent, and a title leaving a service is
        // exactly the case where the stored badge must stop claiming it.
        if let fresh = SavedProvider.main(from: providerResults,
                                          subscribedTo: Set(StreamingPreferences.providerIDs)) {
            if providers[String(id)] != fresh {
                providers[String(id)] = fresh
                didChange = true
            }
        } else if providerResults != nil, providers[String(id)] != nil {
            // A successful lookup that lists no subscription service means it
            // genuinely isn't streaming any more.
            providers.removeValue(forKey: String(id))
            didChange = true
        }

        return didChange
    }

    private static func encoded(_ result: Result) -> Data? {
        try? JSONEncoder().encode(result)
    }

    @discardableResult
    static func addToWatchList(result: Result) -> Bool {

        if WatchlistManager.watchlist.contains(result) == false {
            WatchlistManager.watchlist.append(result)
            if let id = result.id {
                addedDates[String(id)] = Date().timeIntervalSince1970
            }
            // Fetch the title's TMDB keywords in the background so Movie
            // Coach's theme profile stays current. Fire-and-forget — the
            // save itself is already done, and a failure just leaves the
            // title for the next launch's enrichment pass.
            Task { await KeywordEnricher.enrich(result) }
            return true
        }
        return false
    }

    static func removeFromWatchList(result: Result) {

        if WatchlistManager.watchlist.contains(result) == true {
            if let index = WatchlistManager.watchlist.firstIndex(of: result) {
                WatchlistManager.watchlist.remove(at: index)
            }
        }
        // Drop the title's folder mapping and saved-date too. If the user
        // re-saves later it should reappear in Uncategorized, not in the
        // old folder, and the "saved a while ago" clock should restart.
        if let id = result.id {
            FolderManager.shared.forget(resultID: id)
            addedDates.removeValue(forKey: String(id))
            providers.removeValue(forKey: String(id))
        }
    }
    
    static func existsInWatchList(result: Result) -> Bool {
        
        return WatchlistManager.watchlist.contains(result)
    }
}
