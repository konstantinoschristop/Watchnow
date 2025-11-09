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
    
    private let service: ServiceInvocation
    
    init(model: ContentDetailsModel,
         service: ServiceInvocation = .init()) {
        
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
    
    func getImages() async {
       
        do {
            self.images = try await service.fetchImages(screenType: screenType, id: id)
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
    
    var details: ResultDetailsReponse? {
        get { model.details }
        set { model.details = newValue }
    }
    
    var collection: CollectionResponse? {
        get { model.collection }
        set { model.collection = newValue }
    }
    
    var images: ImagesResponse? {
        get { model.images }
        set { model.images = newValue }
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
