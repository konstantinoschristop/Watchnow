//
//  TrendingMoviesViewModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 30/11/21.
//

import Foundation

@MainActor
class TrendingMoviesViewModel: ObservableObject {
    
    @Published private(set) var trendingMovies: TrendingMoviesModel = TrendingMoviesModel.init(results: [])
    
    private let service: MovieService
    
    init(service: MovieService) {
        self.service = service
    }
    
    func getTrendingMovies() async {
        
        do {
            self.trendingMovies = try await service.fetchTrendingMovies()
        } catch {
            print(error)
        }
    }
}
