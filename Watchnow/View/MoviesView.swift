//
//  MoviesView.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import SwiftUI

struct MoviesView: View {
    
    @StateObject var moviesViewModel = MoviesViewModel()
    
    var body: some View {
        
        Group {
            if let results = moviesViewModel.upcomingMovies?.results {
                List {
                    TopView(results: results, viewTitle: "Upcoming Movies", screenType: .movie)
                        .listRowSeparatorTint(.clear)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                    
                    if let results = moviesViewModel.popularMovies?.results {
                        BottomView(results: results, viewTitle: "Popular Movies", screenType: .movie)
                            .listRowSeparatorTint(.clear)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                    
                    if let results = moviesViewModel.trendingMovies?.results {
                        BottomView(results: results, viewTitle: "Trending Today", screenType: .movie)
                            .listRowSeparatorTint(.clear)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                .listStyle(.plain)
            } else {
                ProgressView()
            }
        }
        .task {
            await moviesViewModel.getUpcomingMovies()
            await moviesViewModel.getPopularMovies()
            await moviesViewModel.getTrendingMovies()
        }
        .refreshable {
            await moviesViewModel.getUpcomingMovies()
            await moviesViewModel.getPopularMovies()
            await moviesViewModel.getTrendingMovies()
        }
    }
}
