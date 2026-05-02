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
        self.model.isInWatchList   = WatchlistManager.existsInWatchList(result: result)
        self.model.isInWatchedList = WatchedManager.shared.existsInWatched(result: result)
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
            self.details = try await service.fetchDetails(screenType: screenType, id: id)
            if let firstSeason = details?.seasons?.first(where: { $0.air_date != nil }) {
                self.selectedSeason = firstSeason
            }
        } catch {
            apiError = true
        }
        
        checkIfFetchingIsFinished()
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

    var isInWatchedList: Bool {
        get { model.isInWatchedList }
        set { model.isInWatchedList = newValue }
    }
    
    var viewModelFinishedFetching: Bool {
        get { model.viewModelFinishedFetching }
        set { model.viewModelFinishedFetching = newValue }
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
}
