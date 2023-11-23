//
//  ContentView.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/7/21.
//

import SwiftUI
import PartialSheet
import TipKit

struct ContentView: View {
    
    var body: some View {
        TabView {
            NavigationStack {
                let model = MoviesModel()
                let vm = MoviesViewModel(model: model)
                MoviesView(moviesViewModel: vm)
                    .background(Color(.systemGray6))
            }
            .attachPartialSheetToRoot()
            .tabItem {
                Label("Movies", systemImage: "film")
            }
            
            NavigationStack {
                let model = SeriesModel()
                let vm = SeriesViewModel(model: model)
                SeriesView(seriesViewModel: vm)
                    .background(Color(.systemGray6))
            }
            .attachPartialSheetToRoot()
            .tabItem {
                Label("Series", systemImage: "tv.inset.filled")
            }
            
            NavigationStack {
                let model = SearchModel()
                let vm = SearchViewModel(model: model)
                SearchView(searchVM: vm)
                    .background(Color(.systemGray6))
                    .navigationBarTitle("Search")
                    .navigationBarTitleDisplayMode(.automatic)
            }
            .attachPartialSheetToRoot()
            .tabItem {
                Label("Search", systemImage: "magnifyingglass.circle")
            }
            
            NavigationStack {
                let model = WatchlistModel()
                let vm = WatchlistViewModel(model: model)
                WatchlistView(watchlistViewModel: vm)
                    .background(Color(.systemGray6))
                    .navigationBarTitle("Watchlist")
                    .navigationBarTitleDisplayMode(.automatic)
            }
            .attachPartialSheetToRoot()
            .tabItem {
                Label("Watchlist", systemImage: "list.bullet.circle.fill")
            }
        }
        .task {
            if #available(iOS 17.0, *) {
                try? Tips.configure([
                    .displayFrequency(.immediate),
                    .datastoreLocation(.applicationDefault)
                ])
            } else {
                // Fallback on earlier versions
            }
        }
    }
}
