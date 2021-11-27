//
//  MoviesView.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import SwiftUI

struct MoviesView: View {
    
    @StateObject var upcomingMoviesVM = UpcomingMoviesViewModel(service: MovieService())
    @StateObject var popularMoviesVM = PopularMoviesViewModel(service: MovieService())
    
    var body: some View {

        VStack(spacing: -10) {
            
            if let results = upcomingMoviesVM.upcomingMovies.results {
                TopView(results: results, viewTitle: "Upcoming Movies")
            } else {
                ProgressView()
            }
          
            Spacer()
            
            if let results = popularMoviesVM.popularMovies.results {
                BottomView(results: results, viewTitle: "Popular Movies")
            } else {
                ProgressView()
            }
        }
        .task {
            await upcomingMoviesVM.getUpcomingMovies()
            await popularMoviesVM.getPopularMovies()
        }
    }
}
