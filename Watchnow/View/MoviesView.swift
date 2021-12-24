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
    @StateObject var trendingMoviesVM = TrendingMoviesViewModel(service: MovieService())
    
    var body: some View {
        
        Group {
            if upcomingMoviesVM.upcomingMovies.results.isEmpty {
                ProgressView()
            } else {
                List {
                    TopView(results: upcomingMoviesVM.upcomingMovies.results, viewTitle: "Upcoming Movies", screenType: .movie)
                        .listRowSeparatorTint(.clear)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                    
                    BottomView(results: popularMoviesVM.popularMovies.results, viewTitle: "Popular Movies", screenType: .movie)
                        .listRowSeparatorTint(.clear)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    
                    BottomView(results: trendingMoviesVM.trendingMovies.results, viewTitle: "Trending Today", screenType: .movie)
                        .listRowSeparatorTint(.clear)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .listStyle(.plain)
            }
        }
        .task {
            await upcomingMoviesVM.getUpcomingMovies()
            await popularMoviesVM.getPopularMovies()
            await trendingMoviesVM.getTrendingMovies()
        }
        .refreshable {
            await upcomingMoviesVM.getUpcomingMovies()
            await popularMoviesVM.getPopularMovies()
            await trendingMoviesVM.getTrendingMovies()
        }
    }
}
