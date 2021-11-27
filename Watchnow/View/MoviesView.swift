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

        List {
            
            if let results = upcomingMoviesVM.upcomingMovies.results {
                TopView(results: results, viewTitle: "Upcoming Movies")
                    .listRowSeparatorTint(.clear)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            } else {
                ProgressView()
            }
          
            Spacer()
            
            if let results = popularMoviesVM.popularMovies.results {
                BottomView(results: results, viewTitle: "Popular Movies")
                    .listRowSeparatorTint(.clear)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            } else {
                ProgressView()
            }
        }
        .listStyle(.plain)
        .task {
            await upcomingMoviesVM.getUpcomingMovies()
            await popularMoviesVM.getPopularMovies()
        }
        .refreshable {
            await upcomingMoviesVM.getUpcomingMovies()
            await popularMoviesVM.getPopularMovies()
        }
    }
}
