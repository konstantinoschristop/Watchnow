//
//  ContentView.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/7/21.
//

import SwiftUI
import TipKit

struct ContentView: View {
    
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
        .task {
            try? Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
        }
    }
}

extension ContentView {
    
    private var moviesTabContent: some View {
        NavigationStack {
            let model = MoviesModel()
            let vm = MoviesViewModel(model: model)
            MoviesView(moviesViewModel: vm)
                .background(Color(.systemGray6))
                .navigationBarTitle("Movies")
        }
    }
    
    private var seriesTabContent: some View {
        NavigationStack {
            let model = SeriesModel()
            let vm = SeriesViewModel(model: model)
            SeriesView(seriesViewModel: vm)
                .background(Color(.systemGray6))
                .navigationBarTitle("Series")
        }
    }
    
    private var searchTabContent: some View {
        NavigationStack {
            let model = SearchModel()
            let vm = SearchViewModel(model: model)
            SearchView(searchVM: vm)
                .background(Color(.systemGray6))
                .navigationBarTitle("Search")
                .navigationBarTitleDisplayMode(.automatic)
        }
    }
    
    private var watchlistTabContent: some View {
        NavigationStack {
            let model = WatchlistModel()
            let vm = WatchlistViewModel(model: model)
            WatchlistView(watchlistViewModel: vm)
                .background(Color(.systemGray6))
                .navigationBarTitle("Watchlist")
                .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
