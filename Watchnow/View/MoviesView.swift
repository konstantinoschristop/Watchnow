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
                    TopView(results: results,
                            viewTitle: "Upcoming Movies",
                            screenType: .movie,
                            viewModel: moviesViewModel,
                            viewSection: .upcomingMovies)
                        .listRowSeparatorTint(.clear)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                    
                    if let results = moviesViewModel.getPopularMovieResults() {
                        BottomView(results: results,
                                   viewTitle: "Popular Movies",
                                   screenType: .movie,
                                   viewModel: moviesViewModel,
                                   viewSection: .popularMovies)
                            .listRowSeparatorTint(.clear)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                    
                    if let results = moviesViewModel.getTrendingMovieResults() {
                        BottomView(results: results,
                                   viewTitle: "Trending Today",
                                   screenType: .movie,
                                   viewModel: moviesViewModel,
                                   viewSection: .trendingMovies)
                            .listRowSeparatorTint(.clear)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                .listStyle(.plain)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await moviesViewModel.getUpcomingMovies(page: moviesViewModel.upcomingMoviesCurrentPage)
            await moviesViewModel.getPopularMovies(page: moviesViewModel.popularMoviesCurrentPage)
            await moviesViewModel.getTrendingMovies(page: moviesViewModel.trendingMoviesCurrentPage)
        }
        .refreshable {
            await moviesViewModel.getUpcomingMovies(page: moviesViewModel.upcomingMoviesCurrentPage)
            await moviesViewModel.getPopularMovies(page: moviesViewModel.popularMoviesCurrentPage)
            await moviesViewModel.getTrendingMovies(page: moviesViewModel.trendingMoviesCurrentPage)
        }
        .onChange(of: moviesViewModel.upcomingMoviesCurrentPage) { newValue in
            Task {
                await moviesViewModel.getUpcomingMovies(page: newValue)
            }
        }
        .onChange(of: moviesViewModel.popularMoviesCurrentPage) { newValue in
            Task {
                await moviesViewModel.getPopularMovies(page: newValue)
            }
        }
        .onChange(of: moviesViewModel.trendingMoviesCurrentPage) { newValue in
            Task {
                await moviesViewModel.getTrendingMovies(page: newValue)
            }
        }
    }
}
