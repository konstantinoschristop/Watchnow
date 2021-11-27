//
//  UpcomingMoviesViewModel.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import Foundation
import SwiftUI

@MainActor
class UpcomingMoviesViewModel: ObservableObject {
    
    @Published private(set) var upcomingMovies: UpcomingMoviesModel = UpcomingMoviesModel.init(results: [])
    
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
