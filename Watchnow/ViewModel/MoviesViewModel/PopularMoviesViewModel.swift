//
//  PopularMoviesViewModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation

@MainActor
class PopularMoviesViewModel: ObservableObject {
    
    @Published private(set) var popularMovies: PopularMoviesModel = PopularMoviesModel.init(results: [])
    
    private let service: MovieService
    
    init(service: MovieService) {
        self.service = service
    }
    
    func getPopularMovies() async {
        
        do {
            self.popularMovies = try await service.fetchPopularMovies()
        } catch {
            print(error)
        }
    }
}
