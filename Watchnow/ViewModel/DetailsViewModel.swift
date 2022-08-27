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
    @Published var isInWatchList: Bool
    @Published var imageHeight: Float = 400
    
    private let service: ServiceInvaction
    let screenType: ScreenTypes
    let id: String
    
    init(service: ServiceInvaction,
         screenType: ScreenTypes,
         id: String,
         result: Result) {
        
        self.service = service
        self.screenType = screenType
        self.id = id
        self.isInWatchList = WatchlistManager.watchlist.contains(result)
    }
    
    func getCredits() async {
        
        do {
            self.credits = try await service.fetchCredits(screenType: self.screenType, id: self.id)
        } catch {
            print(error)
        }
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
    }
}
