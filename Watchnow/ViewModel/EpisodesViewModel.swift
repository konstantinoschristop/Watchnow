//
//  EpisodesViewModel.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 15/8/22.
//

import Foundation

@MainActor
class EpisodesViewModel: ObservableObject {
    
    @Published private(set) var episodes: EpisodesModel?
    
    private let service: ServiceInvaction
    let seriesID: Int
    
    init(service: ServiceInvaction,
         seriesID: Int) {
        
        self.service = service
        self.seriesID = seriesID
    }
    
    func getEpisodes(seasonNumber: Int) async {
        
        self.resetEpisodes()
        
        do {
            self.episodes = try await service.fetchEpisodes(seriesID: self.seriesID, seasonNumber: seasonNumber)
        } catch {
            print(error)
        }
    }
    
    func resetEpisodes() {
        DispatchQueue.main.async {
            self.episodes = nil
        }
    }
}
