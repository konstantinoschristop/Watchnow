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
    
    @ObservedObject var watchlistViewModel: WatchlistViewModel
    @State var selectedTab: WatchlistModel.Tab = .movies
    @Namespace private var namespace
    
    var body: some View {
        
        tabView
        .onAppear {
            watchlistViewModel.refreshDataIfNeeded()
        }
        .toast(isPresenting: $watchlistViewModel.showRemovedAlert, alert: {
            AlertToast(displayMode: .hud, type: .systemImage("x.circle", .red), title: "Removed from Watchlist")
        })
    }
    
    @ViewBuilder
    var pickerView: some View {
        Picker("", selection: $selectedTab) {
            ForEach(WatchlistModel.Tab.allCases, id: \.self) { tab in
                Text(tab.title)
                    .tag(tab.rawValue)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private func section(title: String, results: Binding<[Result]>) -> some View {
        VStack(spacing: 0) {
            List {
                Text(title)
                    .font(.system(size: 25, weight: .heavy))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top)
                    .listRowSeparatorTint(.clear)
                    .listRowBackground(Color(.background))
                GenericListView(results: results,
                                viewModel: watchlistViewModel,
                                namespace: namespace)
            }
            .listStyle(.plain)
        }
    }
    
    @ViewBuilder
    var tabView: some View {
        
        Group {
            switch selectedTab {
            case .movies:
                section(title: selectedTab.title, results: $watchlistViewModel.savedMovies)
            case .series:
                section(title: selectedTab.title, results: $watchlistViewModel.savedSeries)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                pickerView
            }
        }
    }
}
