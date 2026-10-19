//
//  ContentDetailsViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import Foundation

@MainActor
class ContentDetailsViewModel: ObservableObject {
    
    @Published private var model: ContentDetailsModel
    /// Results that have landed but not yet reached the page. The section
    /// requests come back within moments of each other, and every publish
    /// re-renders the whole details page — mid-way through the arrival of
    /// the section before. So they're gathered here and published together
    /// a beat later, and arrive as one staggered entrance (see
    /// `sectionArrival`). Reads see them straight away.
    private var staged: ContentDetailsModel?
    private var flush: Task<Void, Never>?
    @Published var apiError: Bool = false
    @Published var selectedSeason: Season = Season()
    
    private let service: any DetailServiceProtocol

    init(model: ContentDetailsModel,
         service: any DetailServiceProtocol = ServiceInvocation()) {
        
        self.model = model
        self.service = service
        self.model.isInWatchList = WatchlistManager.existsInWatchList(result: result)
    }
    
    /// The model as it stands, including results not yet published.
    private var current: ContentDetailsModel { staged ?? model }

    /// Changes the model. `now` publishes at once — with anything staged —
    /// for what the reader did or is waiting on; otherwise the change joins
    /// whatever else lands in the next moment.
    private func write(now: Bool = false, _ change: (inout ContentDetailsModel) -> Void) {
        var next = current
        change(&next)
        if now {
            flush?.cancel()
            flush = nil
            staged = nil
            model = next
            return
        }
        staged = next
        guard flush == nil else { return }
        flush = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard let self, !Task.isCancelled else { return }
            self.flush = nil
            if let staged = self.staged {
                self.staged = nil
                self.model = staged
            }
        }
    }

    private func checkIfFetchingIsFinished() {
        
        if details != nil && credits != nil {
            self.viewModelFinishedFetching = true
        }
    }
    
    func getCredits() async {
        
        do {
            self.credits = try await service.fetchCredits(screenType: self.screenType, id: self.id)
        } catch {
            apiError = true
        }
        
        checkIfFetchingIsFinished()
    }
    
    /// The "More like this" row — and Movie Coach's "similar to something
    /// you saved" — prefer TMDB's recommendations ("people who liked this
    /// also liked") over its similar-titles endpoint, which matches on
    /// shared keywords and turns up things like a 1973 German melodrama
    /// for Inception, or a Japanese anime with one vote for Breaking Bad.
    /// Similar is the fallback for titles too obscure to have
    /// recommendations.
    ///
    /// Titles almost nobody has rated are left out either way, unless that
    /// would leave the row nearly empty.
    func getSimilars() async {
        var candidates: [Result] = []
        if let numericID = result.id,
           let recommended = try? await service.fetchRecommendations(screenType: screenType, id: numericID) {
            candidates = recommended.results
        }
        if candidates.isEmpty {
            do {
                candidates = try await service.fetchSimilars(screenType: self.screenType, id: self.id).results ?? []
            } catch {
                apiError = true
                return
            }
        }
        let established = candidates.filter { ($0.vote_count ?? 0) >= 25 }
        self.similar = GetSimilarModel(page: 1,
                                       results: established.count >= 4 ? established : candidates,
                                       total_pages: 1,
                                       total_results: nil)
    }
    
    func getReviews() async {
        
        do {
            self.reviews = try await service.fetchReviews(screenType: self.screenType, id: self.id)
        } catch {
            apiError = true
        }
    }
    
    func getVideos() async {
        
        do {
            self.videos = try await service.fetchVideos(screenType: screenType, id: id)
        } catch {
            apiError = true
        }
    }
    
    func getDetails() async {

        do {
            let fetched = try await service.fetchDetails(screenType: screenType, id: id)
            self.details = fetched
            // Result may have been instantiated as a deeplink stub (only
            // id + media_type populated). Backfill the fields the hero
            // reads directly — title, poster/backdrop — from the freshly
            // fetched details so the screen renders correctly instead of
            // showing "- -" with a broken image.
            let merged = mergeIntoResult(current.result, from: fetched)
            write(now: true) { $0.result = merged }
            if let firstSeason = fetched.seasons?.first(where: { $0.air_date != nil }) {
                self.selectedSeason = firstSeason
            }
        } catch {
            apiError = true
        }

        checkIfFetchingIsFinished()
    }

    /// Fills in any nil fields on `result` from the freshly-fetched
    /// `details`. Used to recover from the deeplink stub case — the
    /// regular navigation flow constructs a fully-populated Result from
    /// list responses, so for those the merge is a no-op.
    private func mergeIntoResult(_ result: Result,
                                 from details: ResultDetailsResponse) -> Result {
        Result(
            backdrop_path:     result.backdrop_path     ?? details.backdrop_path,
            first_air_date:    result.first_air_date    ?? details.first_air_date,
            genre_ids:         result.genre_ids,
            id:                result.id                ?? details.id,
            original_title:    result.original_title,
            name:              result.name              ?? details.name,
            origin_country:    result.origin_country,
            original_language: result.original_language,
            original_name:     result.original_name,
            overview:          result.overview          ?? details.overview,
            popularity:        result.popularity,
            poster_path:       result.poster_path       ?? details.poster_path,
            release_date:      result.release_date      ?? details.release_date,
            title:             result.title             ?? details.title,
            video:             result.video,
            vote_average:      result.vote_average      ?? details.vote_average,
            vote_count:        result.vote_count        ?? details.vote_count,
            media_type:        result.media_type,
            profile_path:      result.profile_path,
            castID:            result.castID,
            runtime:           result.runtime,
            known_for:         result.known_for
        )
    }
    
    func getCollection() async {
        
        guard let collectionID = details?.belongs_to_collection?.id else {
            return
        }
       
        do {
            self.collection = try await service.fetchCollection(collectionID: collectionID)
        } catch {
            apiError = true
        }
    }
    
    func getWatchProviders() async {
        do {
            self.watchProviders = try await service.fetchWatchProviders(screenType: screenType, id: id)
        } catch {
            apiError = true
        }
    }

    /// Keywords for the current title, cache-first. Unlike the other
    /// fetchers this never sets `apiError`: keywords only sharpen Movie
    /// Coach, so a failure quietly falls back to whatever (possibly stale)
    /// cache exists and the screen carries on.
    func getKeywords() async {
        guard screenType != .person, let numericID = result.id else { return }

        if KeywordStore.isFresh(type: screenType, id: numericID) {
            self.keywords = KeywordStore.keywords(type: screenType, id: numericID) ?? []
            return
        }

        do {
            let response = try await service.fetchKeywords(screenType: screenType, id: id)
            let names = response.all.compactMap(\.name)
            KeywordStore.store(names, type: screenType, id: numericID)
            self.keywords = names
        } catch {
            self.keywords = KeywordStore.keywords(type: screenType, id: numericID) ?? []
        }
    }
    
    /// Push what this screen has just learned back into the saved copy.
    ///
    /// The details endpoint is the only place the app sees a title's current
    /// artwork, rating and availability, and the watchlist can hold an entry
    /// for years — long enough for TMDB to replace the poster it was saved
    /// with. Opening a saved title is therefore the natural moment to
    /// reconcile the two, and it costs no extra requests: everything used
    /// here was already fetched to render this screen.
    ///
    /// A no-op when the title isn't saved, so the caller doesn't have to ask.
    @discardableResult
    func syncWatchlistEntry() -> Bool {
        guard isInWatchList, let id = result.id else { return false }
        return WatchlistManager.refreshSavedEntry(id: id,
                                                  details: details,
                                                  providerResults: watchProviderSafe)
    }

    func createShareLink() -> String {
        return "https://www.themoviedb.org/" + screenType.rawValue + "/\(id)"
    }
}

extension ContentDetailsViewModel {
    
    var credits: ResultCreditsResponse? {
        get { current.credits }
        set { write { $0.credits = newValue } }
    }
    
    var similar: GetSimilarModel? {
        get { current.similar }
        set { write { $0.similar = newValue } }
    }
    
    var reviews: ResultReviewsResponse? {
        get { current.reviews }
        set { write { $0.reviews = newValue } }
    }
    
    var videos: VideoResponse? {
        get { current.videos }
        set { write { $0.videos = newValue } }
    }
    
    /// The first thing the page draws — straight to it.
    var details: ResultDetailsResponse? {
        get { current.details }
        set { write(now: true) { $0.details = newValue } }
    }
    
    var collection: CollectionResponse? {
        get { current.collection }
        set { write { $0.collection = newValue } }
    }
    
    var watchProviders: WatchProvidersResponse? {
        get { current.watchProviders }
        set { write { $0.watchProviders = newValue } }
    }

    var keywords: [String]? {
        get { current.keywords }
        set { write { $0.keywords = newValue } }
    }
    
    /// The reader's own tap — straight to the page.
    var isInWatchList: Bool {
        get { current.isInWatchList }
        set { write(now: true) { $0.isInWatchList = newValue } }
    }


    var viewModelFinishedFetching: Bool {
        get { current.viewModelFinishedFetching }
        set { write { $0.viewModelFinishedFetching = newValue } }
    }

    /// The last of the loading — publishes it, with anything still staged.
    var allSectionsLoaded: Bool {
        get { current.allSectionsLoaded }
        set { write(now: true) { $0.allSectionsLoaded = newValue } }
    }
    
    var screenType: ScreenTypes  {
        get { current.screenType }
    }
    
    var result: Result {
        get { current.result }
    }
    
    var id: String {
        guard let id = result.id else {
            return ""
        }
        
        return String(id)
    }
}

extension ContentDetailsViewModel {
    var trailerURL: URL? {
        videos?.getVideoURL()
    }

    var castSafe: [Cast] {
        credits?.cast ?? []
    }

    var hasGenres: Bool {
        !(details?.genres?.isEmpty ?? true)
    }

    var genresSafe: [Genres] {
        details?.genres ?? []
    }

    var hasSeasons: Bool {
        details?.getSeasons()?.isEmpty == false &&
        details?.number_of_seasons != nil &&
        details?.number_of_episodes != nil &&
        details?.name != nil &&
        details?.id != nil
    }

    var seasonsSafe: [Season] {
        details?.getSeasons() ?? []
    }

    var hasWatchProviders: Bool {
        if let provider = watchProviderSafe {
            return !(provider.flatrate?.isEmpty ?? true)
                || !(provider.rent?.isEmpty ?? true)
                || !(provider.buy?.isEmpty ?? true)
        }
        return false
    }

    var watchProviderSafe: ProviderResults? {
        watchProviders?.results?[Self.currentRegionCode]
    }

    /// The age rating for the user's region.
    var certification: String? {
        details?.certification(region: Self.currentRegionCode)
    }

    /// The streaming services this title is on that the user has told us
    /// they pay for (Movie Night's "which do you have?"), by name.
    var ownedServiceNames: [String] {
        let owned = Set(StreamingPreferences.providerIDs)
        guard !owned.isEmpty else { return [] }
        var seen = Set<Int>()
        return (watchProviderSafe?.flatrate ?? []).compactMap { provider in
            guard let id = provider.providerID, owned.contains(id), seen.insert(id).inserted else { return nil }
            return provider.providerName
        }
    }

    /// User's actual region (e.g. "GR", "DE", "US") — taken from
    /// Settings → General → Language & Region → Region.
    ///
    /// Previously this lookup used `Locale.current.language.region`, which
    /// returns the region tag of the *language* (English-US → "US"), not
    /// the user's actual location. A user in Greece running their phone
    /// in English would consequently see US streaming providers. Reading
    /// `Locale.current.region` instead returns the region the user
    /// explicitly chose in Settings, decoupled from their language.
    /// Falls back to "US" if the device for some reason has no region
    /// set, since TMDB always has US data and an empty providers card
    /// is worse than the wrong country's card.
    private static var currentRegionCode: String {
        Locale.current.region?.identifier ?? "US"
    }

    /// TMDB-hosted "where to watch" URL for the current region, when
    /// available. This is the URL TMDB returns in the `link` field of
    /// the /watch/providers response — it points to a themoviedb.org
    /// page (e.g. themoviedb.org/movie/123/watch?locale=US) which then
    /// mediates to JustWatch and the actual provider deeplinks.
    /// TMDB's API docs explicitly recommend linking to this URL rather
    /// than bypassing to JustWatch directly.
    var watchNowURL: URL? {
        guard let link = watchProviderSafe?.link, !link.isEmpty else { return nil }
        return URL(string: link)
    }

    var hasCast: Bool {
        !(credits?.cast?.isEmpty ?? true)
    }

    var hasSimilars: Bool {
        !(similar?.results?.isEmpty ?? true)
    }

    var similarsSafe: [Result] {
        similar?.results ?? []
    }

    var hasReviews: Bool {
        !(reviews?.results?.isEmpty ?? true)
    }

    var reviewsSafe: [Reviews] {
        reviews?.results ?? []
    }

    var hasCollection: Bool {
        if let parts = collection?.parts { return !parts.isEmpty }
        return false
    }

    var collectionSafe: [Result] {
        collection?.parts ?? []
    }

    // MARK: - Reminders

    /// Parsed release / first-air date if the title is unreleased. Returns
    /// nil for titles that already aired (no reminder needed) or for
    /// person results / titles missing a date.
    var futureReleaseDate: Date? {
        guard screenType != .person else { return nil }
        let raw = details?.release_date ?? details?.first_air_date ?? ""
        guard !raw.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .iso8601)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: raw) else { return nil }
        return date > Date() ? date : nil
    }

    var reminderIdentifier: String? {
        guard let id = result.id else { return nil }
        return ReminderManager.titleIdentifier(resultID: id)
    }

    // MARK: - Alerts

    /// What the bell in the nav bar controls on this screen.
    ///
    /// Two jobs, never at once. An unreleased title gets the manual
    /// release reminder the bell has meant since v1.3 — untouched. Anything
    /// already out is instead the per-title switch for the automatic alerts
    /// this release adds, which is the only control a user has over an
    /// episode or "now streaming" notification for that title.
    enum BellMode: Equatable {
        case releaseReminder(Date)
        case automaticAlerts
    }

    var bellMode: BellMode? {
        if let date = futureReleaseDate { return .releaseReminder(date) }
        guard isInWatchList, result.id != nil, screenType != .person else { return nil }
        return .automaticAlerts
    }

    /// Whether this title is currently muted. Saved titles are unmuted by
    /// default — `AlertPreferences` stores exceptions, never follows.
    var isAlertMuted: Bool {
        guard let id = result.id else { return false }
        return AlertPreferences.isOptedOut(id)
    }

    /// What will actually reach the user if this title stays unmuted, given
    /// the global switches. Worded for the bell's accessibility hint, so a
    /// VoiceOver user is told the truth rather than "alerts are on" when
    /// both switches are off in Settings.
    var alertHint: String {
        guard let id = result.id else { return "" }
        let kinds = AutoAlertPolicy.alertKinds(
            for: AlertPreferences.policyInputs(forID: id, isSaved: isInWatchList))
        if kinds.isEmpty {
            return String(localized: "Alerts are switched off for every title in Settings")
        }
        if kinds.contains(.episode), kinds.contains(.streaming) {
            return screenType == .tv
                ? String(localized: "New episodes, and when it lands on a service you have", comment: "What this title's alerts cover")
                : String(localized: "When it lands on a service you have", comment: "What this title's alerts cover")
        }
        if kinds.contains(.episode) {
            return screenType == .tv
                ? String(localized: "New episodes", comment: "What this title's alerts cover")
                : String(localized: "Alerts are limited to new episodes in Settings")
        }
        return String(localized: "When it lands on a service you have", comment: "What this title's alerts cover")
    }

    var reminderDeepLink: DeepLink? {
        guard let id = result.id else { return nil }
        let mediaType: DeepLink.MediaType = (screenType == .movie) ? .movie : .tv
        return DeepLink(id: id, mediaType: mediaType)
    }

    // MARK: - Taste

    /// Genre ids to attribute an explicit "I like this" to. Prefers the
    /// fetched details (always present) over `result.genre_ids`, which is nil
    /// when the screen was opened from a deeplink stub.
    var likeGenreIDs: [Int] {
        let fromDetails = (details?.genres ?? []).compactMap(\.id)
        return fromDetails.isEmpty ? (result.genre_ids ?? []) : fromDetails
    }


    // MARK: - Movie Coach

    /// Facts handed to Movie Coach, assembled from data this screen has
    /// already fetched — no extra network calls.
    ///
    /// Nil until every parallel fetch has settled (and never for people), so
    /// the card generates once with the full picture rather than re-running
    /// as each request lands.
    /// Posters for the Coach card's fan: this title in front, and behind it
    /// up to two from the user's own list that sit near it — titles TMDB
    /// calls similar first, then ones sharing a genre.
    ///
    /// Only ever saved titles. The fan reads as "because of these", so a
    /// stranger's poster behind this one would be a claim Coach isn't
    /// making. With nothing related saved, the fan is just this poster.
    var coachPosterPaths: [String] {
        guard let own = result.poster_path ?? details?.poster_path else { return [] }
        let similarIDs = Set(similarsSafe.compactMap(\.id))
        let genres = Set(likeGenreIDs)
        let saved = WatchlistManager.watchlist.filter { $0.id != result.id && $0.poster_path != nil }
        let isSimilar: (Result) -> Bool = { $0.id.map(similarIDs.contains) ?? false }
        let sharesGenre: (Result) -> Bool = { !Set($0.genre_ids ?? []).isDisjoint(with: genres) }
        let companions = saved.filter(isSimilar) + saved.filter { !isSimilar($0) && sharesGenre($0) }
        return [own] + companions.prefix(2).compactMap(\.poster_path)
    }

    var coachContext: MovieCoachContext? {
        guard screenType != .person, allSectionsLoaded, details != nil else { return nil }
        return MovieCoachContext.build(result: result,
                                       screenType: screenType,
                                       details: details,
                                       cast: castSafe,
                                       similars: similarsSafe,
                                       providerResults: watchProviderSafe,
                                       keywords: keywords ?? [])
    }
}
