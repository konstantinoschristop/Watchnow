//
//  ContentView.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/7/21.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        TabView {
            NavigationView {
                MoviesView()
                    .background(Color(.systemGray6))
                    .navigationBarTitle("Movies")
                    .navigationBarTitleDisplayMode(.automatic)
            }
            .tabItem {
                Label("Movies", systemImage: "film")
            }
            .navigationViewStyle(.stack)
            
            NavigationView {
                SerieView()
                    .background(Color(.systemGray6))
                    .navigationBarTitle("Series")
                    .navigationBarTitleDisplayMode(.automatic)
            }
            .tabItem {
                Label("Series", systemImage: "tv.inset.filled")
            }
            .navigationViewStyle(.stack)
            
            NavigationView {
               SearchView()
                    .background(Color(.systemGray6))
                    .navigationBarTitle("Search")
                    .navigationBarTitleDisplayMode(.automatic)
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass.circle")
            }
            .navigationViewStyle(.stack)
            
            NavigationView {
                WatchlistView()
                    .background(Color(.systemGray6))
                     .navigationBarTitle("Watchlist")
                     .navigationBarTitleDisplayMode(.automatic)
            }
            .tabItem {
                Label("Watchlist", systemImage: "list.bullet.circle.fill")
            }
            .navigationViewStyle(.stack)
        }
    }
}
