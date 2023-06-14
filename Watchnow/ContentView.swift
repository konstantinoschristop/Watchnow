//
//  ContentView.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/7/21.
//

import SwiftUI
import PartialSheet

struct ContentView: View {
    
    var body: some View {
        TabView {
            NavigationView {
                MoviesView()
                    .background(Color(.systemGray6))
                    .navigationBarHidden(true)
            }
            .attachPartialSheetToRoot()
            .tabItem {
                Label("Movies", systemImage: "film")
            }
            
            NavigationView {
                SerieView()
                    .background(Color(.systemGray6))
                    .navigationBarHidden(true)
            }
            .attachPartialSheetToRoot()
            .tabItem {
                Label("Series", systemImage: "tv.inset.filled")
            }
            
            NavigationView {
               SearchView()
                    .background(Color(.systemGray6))
                    .navigationBarTitle("Search")
                    .navigationBarTitleDisplayMode(.automatic)
            }
            .attachPartialSheetToRoot()
            .tabItem {
                Label("Search", systemImage: "magnifyingglass.circle")
            }
            
            NavigationView {
                WatchlistView()
                    .background(Color(.systemGray6))
                     .navigationBarTitle("Watchlist")
                     .navigationBarTitleDisplayMode(.automatic)
            }
            .attachPartialSheetToRoot()
            .tabItem {
                Label("Watchlist", systemImage: "list.bullet.circle.fill")
            }
        }
    }
}
