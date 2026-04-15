//
//  ContentView.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/7/21.
//

import SwiftUI

struct ContentView: View {

    @StateObject private var moviesViewModel = MoviesViewModel(model: MoviesModel())
    @StateObject private var seriesViewModel = SeriesViewModel(model: SeriesModel())
    @StateObject private var searchViewModel = SearchViewModel(model: SearchModel())
    @StateObject private var watchlistViewModel = WatchlistViewModel(model: WatchlistModel())

    var body: some View {
        TabView {
            Tab("Movies", systemImage: "film") {
                moviesTabContent
            }
            Tab("Series", systemImage: "tv.inset.filled") {
                seriesTabContent
            }
            Tab("Search", systemImage: "magnifyingglass.circle", role: .search) {
                searchTabContent
            }
            Tab("Watchlist", systemImage: "list.bullet.circle.fill") {
                watchlistTabContent
            }
        }
        .minimizeTabBar()
    }
}

extension ContentView {
    
    private var moviesTabContent: some View {
        NavigationStack {
            MoviesView(moviesViewModel: moviesViewModel)
                .background(Color(.background))
                .navigationTitle("Movies")
        }
    }

    private var seriesTabContent: some View {
        NavigationStack {
            SeriesView(seriesViewModel: seriesViewModel)
                .background(Color(.background))
                .navigationTitle("Series")
        }
    }

    private var searchTabContent: some View {
        NavigationStack {
            SearchView(viewModel: searchViewModel)
                .background(Color(.background))
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.automatic)
        }
    }

    private var watchlistTabContent: some View {
        NavigationStack {
            WatchlistView(watchlistViewModel: watchlistViewModel)
                .background(Color(.background))
                .navigationTitle("Watchlist")
                .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
