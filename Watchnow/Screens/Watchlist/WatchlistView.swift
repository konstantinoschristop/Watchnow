//
//  WatchlistView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation
import SwiftUI
import AlertToast

struct WatchlistView: View {
    
    @StateObject var watchlistViewModel: WatchlistViewModel
    @State var selectedTab = "Movies"
    
    var body: some View {
        
       // listView
        tabView
        .onAppear {
            watchlistViewModel.refreshDataIfNeeded()
        }
        .toast(isPresenting: $watchlistViewModel.showRemovedAlert, alert: {
            AlertToast(displayMode: .banner(.slide), type: .systemImage("x.circle", .red), title: "Removed from Watchlist")
        })
    }
    
    func getSectionTitle(title: String, sectionType: ScreenTypes) -> some View {
        
        return HStack {
            Text(title)
                .font(.system(size: 25, weight: .heavy))
            Spacer()
            Button {
                withAnimation(.easeInOut) {
                    watchlistViewModel.sectionArrowAction(screenType: sectionType)
                }
            } label: {
                Image(systemName: watchlistViewModel.getSectionArrowIcon(screenType: sectionType))
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 3)
            }
        }
        .listRowSeparatorTint(.clear)
        .listRowBackground(Color(.systemGray6))
        .padding(.init(top: 10, leading: 0, bottom: 5, trailing: 0))
    }
    
    var listView: some View {
        VStack(spacing: 0) {
            if watchlistViewModel.isWatchListEmpty() {
                Text("Your watchlist is empty!")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                //                AdBannerView()
                //                    .background(.blue)
                //                    .frame(height: 50)
                //                    .padding(.bottom)
            } else {
                List {
                    if let movies = watchlistViewModel.savedMovies,
                       movies.isEmpty == false {
                        
                        self.getSectionTitle(title: "Movies", sectionType: .movie)
                        
                        if watchlistViewModel.showingMovies {
                            GenericListView(results: movies, viewModel: watchlistViewModel)
                        }
                    }
                    
                    if let series = watchlistViewModel.savedSeries,
                       series.isEmpty == false {
                        
                        self.getSectionTitle(title: "TV Series", sectionType: .tv)
                        
                        if watchlistViewModel.showingSeries {
                            GenericListView(results: series, viewModel: watchlistViewModel)
                        }
                    }
                    //
                    //                        AdBannerView()
                    //                            .frame(height: 50)
                    //                            .padding(.bottom)
                }
                .listStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    var pickerView: some View {
        Picker("", selection: $selectedTab) {
            Text("Movies")
                .tag("Movies")
            Text("TV Series")
                .tag("TV Series")
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    @ViewBuilder
    var tabView: some View {
        
        Group {
            if let movies = watchlistViewModel.savedMovies,
               movies.isEmpty == false,
               selectedTab == "Movies" {
                
                VStack(spacing: 0) {
                    List {
                        Text("Movies")
                            .font(.system(size: 25, weight: .heavy))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top)
                            .listRowSeparatorTint(.clear)
                            .listRowBackground(Color(.systemGray6))
                        GenericListView(results: movies, viewModel: watchlistViewModel)
                    }
                    .listStyle(.plain)
                }
            }
            
            if let series = watchlistViewModel.savedSeries,
               series.isEmpty == false,
               selectedTab == "TV Series" {
                
                VStack(spacing: 0) {
                    List {
                        Text("TV Series")
                            .font(.system(size: 25, weight: .heavy))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top)
                            .listRowSeparatorTint(.clear)
                            .listRowBackground(Color(.systemGray6))
                        GenericListView(results: series, viewModel: watchlistViewModel)
                    }
                    .listStyle(.plain)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                pickerView
            }
        }
    }
}
