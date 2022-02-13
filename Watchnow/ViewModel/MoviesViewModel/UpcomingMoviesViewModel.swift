//
//  UpcomingMoviesViewModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation

@MainActor
class UpcomingMoviesViewModel: ObservableObject {
    
    @Published private(set) var upcomingMovies: UpcomingMoviesModel?
    
    private let service: MovieService
    
    init(service: MovieService) {
        self.service = service
    }
    
    func getUpcomingMovies() async {
        
        do {
            self.upcomingMovies = try await service.fetchUpcomingMovies()
        } catch {
            print(error)
        }
    }
}
