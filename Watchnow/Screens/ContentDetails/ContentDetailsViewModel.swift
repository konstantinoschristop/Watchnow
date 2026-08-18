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
    @Published var apiError: Bool = false
    @Published var selectedSeason: Season = Season()
    
    private let service: any DetailServiceProtocol

    init(model: ContentDetailsModel,
         service: any DetailServiceProtocol = ServiceInvocation()) {
        
        self.model = model
        self.service = service
        self.model.isInWatchList = WatchlistManager.existsInWatchList(result: result)
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
    
    func getSimilars() async {
        
        do {
            self.similar = try await service.fetchSimilars(screenType: self.screenType, id: self.id)
        } catch {
            apiError = true
        }
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
            self.model.result = mergeIntoResult(self.model.result, from: fetched)
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
    
    func createShareLink() -> String {
        return "https://www.themoviedb.org/" + screenType.rawValue + "/\(id)"
    }
}

extension ContentDetailsViewModel {
    
    var credits: ResultCreditsResponse? {
        get { model.credits }
        set { model.credits = newValue }
    }
    
    var similar: GetSimilarModel? {
        get { model.similar }
        set { model.similar = newValue }
    }
    
    var reviews: ResultReviewsResponse? {
        get { model.reviews }
        set { model.reviews = newValue }
    }
    
    var videos: VideoResponse? {
        get { model.videos }
        set { model.videos = newValue }
    }
    
    var details: ResultDetailsResponse? {
        get { model.details }
        set { model.details = newValue }
    }
    
    var collection: CollectionResponse? {
        get { model.collection }
        set { model.collection = newValue }
    }
    
    var watchProviders: WatchProvidersResponse? {
        get { model.watchProviders }
        set { model.watchProviders = newValue }
    }
    
    var isInWatchList: Bool {
        get { model.isInWatchList }
        set { model.isInWatchList = newValue }
    }


    var viewModelFinishedFetching: Bool {
        get { model.viewModelFinishedFetching }
        set { model.viewModelFinishedFetching = newValue }
    }

    var allSectionsLoaded: Bool {
        get { model.allSectionsLoaded }
        set { model.allSectionsLoaded = newValue }
    }
    
    var screenType: ScreenTypes  {
        get { model.screenType }
    }
    
    var result: Result {
        get { model.result }
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

    /// "movie" or "series" — words the taste button.
    var mediaKindLabel: String { screenType == .tv ? "series" : "movie" }

    // MARK: - Movie Coach

    /// Facts handed to Movie Coach, assembled from data this screen has
    /// already fetched — no extra network calls.
    ///
    /// Nil until every parallel fetch has settled (and never for people), so
    /// the card generates once with the full picture rather than re-running
    /// as each request lands.
    var coachContext: MovieCoachContext? {
        guard screenType != .person, allSectionsLoaded, details != nil else { return nil }
        return MovieCoachContext.build(result: result,
                                       screenType: screenType,
                                       details: details,
                                       cast: castSafe,
                                       similars: similarsSafe,
                                       providerResults: watchProviderSafe)
    }
}
