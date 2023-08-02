//
//  DetailsViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import Foundation

@MainActor
class DetailsViewModel: ObservableObject {
    
    @Published private(set) var credits: CreditsModel?
    @Published private(set) var similar: GetSimilarModel?
    @Published private(set) var reviews: ReviewsModel?
    @Published private(set) var videos: VideoModel?
    @Published private(set) var details: ContentDetailsModel?
    @Published private(set) var collection: CollectionModel?
    @Published private(set) var images: ImagesModel?
    @Published private(set) var watchProviders: WatchProvidersResponse?
    @Published var isInWatchList: Bool
    @Published var imageHeight: Float = 400
    @Published private(set) var viewModelFinishedFetching = false
    
    private let service: ServiceInvocation
    let screenType: ScreenTypes
    let id: String
    
    init(service: ServiceInvocation,
         screenType: ScreenTypes,
         id: String,
         result: Result) {
        
        self.service = service
        self.screenType = screenType
        self.id = id
        self.isInWatchList = WatchlistManager.watchlist.contains(result)
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
            print(error)
        }
        
        checkIfFetchingIsFinished()
    }
    
    func getSimilars() async {
        
        do {
            self.similar = try await service.fetchSimilars(screenType: self.screenType, id: self.id)
        } catch {
            print(error)
        }
    }
    
    func getReviews() async {
        
        do {
            self.reviews = try await service.fetchReviews(screenType: self.screenType, id: self.id)
        } catch {
            print(error)
        }
    }
    
    func getVideos() async {
        
        do {
            self.videos = try await service.fetchVideos(screenType: screenType, id: id)
        } catch {
            print(error)
        }
    }
    
    func getDetails() async {
       
        do {
            self.details = try await service.fetchDetails(screenType: screenType, id: id)
        } catch {
            print(error)
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
            print(error)
        }
    }
    
    func getImages() async {
       
        do {
            self.images = try await service.fetchImages(screenType: screenType, id: id)
        } catch {
            print(error)
        }
    }
    
    func getWatchProviders() async {
        do {
            self.watchProviders = try await service.fetchWatchProviders(screenType: screenType, id: id)
        } catch {
            print(error)
        }
    }
    
    func createShareLink() -> String {
        return "https://www.themoviedb.org/" + screenType.rawValue + "/\(id)"
    }
}
