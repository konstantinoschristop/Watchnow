//
//  GenericListView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation
import SwiftUI

struct GenericListView: View {
    
    var results: [Result]
    var viewModel: Any?
    
    var body: some View {
        
        ForEach(results, id: \.self) { result in
            NavigationLink {
                switch result.getMediaType() {
                case "Actor":
                    ActorDetailsView(actorID: result.id)
                default:
                    ContentDetailsView(result: result, screenType: result.media_type == "movie" ? .movie : .tv)
                }
            }
        label: {
            self.constructResult(result: result)
        }
        .listRowSeparatorTint(.clear)
        .listRowBackground(Color(.systemGray6))
        .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: -15))
        .swipeActions {
            if let watchListVM = viewModel as? WatchlistViewModel {
                contructRemoveSwipeAction(result: result, viewModel: watchListVM)
            } else if let searchVM = viewModel as? SearchViewModel {
                switch WatchlistManager.existsInWatchList(result: result) {
                case true:
                    contructRemoveSwipeActionFromSearch(result: result, viewModel: searchVM)
                case false:
                    contructAddSwipeAction(result: result, viewModel: searchVM)
                        .tint(.green)
                }
            }
        }
        }
    }
    
    @MainActor
    func contructAddSwipeAction(result: Result, viewModel: SearchViewModel) -> Button<Label<Text, Image>>? {
        
        return Button (action: {
            WatchlistManager.addToWatchList(result: result)
            viewModel.showAddedAlert = true
            viewModel.listNeedsUpdate = true
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }) {
            Label("Add to Watchlist", systemImage: "bookmark.fill")
        }
    }
    
    @MainActor
    func contructRemoveSwipeAction(result: Result, viewModel: WatchlistViewModel) -> Button<Label<Text, Image>>? {
        
        return Button (role: .destructive, action: {
            WatchlistManager.removeFromWatchList(result: result)
            
            if let vmResults = viewModel.results,
               let index = vmResults.firstIndex(of: result) {
                withAnimation {
                    viewModel.results?.remove(at: index)
                    viewModel.refreshDataIfNeeded()
                    viewModel.showAlert = true
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
            }
        }) {
            Label("Remove", systemImage: "trash")
        }
    }
    
    @MainActor
    func contructRemoveSwipeActionFromSearch(result: Result, viewModel: SearchViewModel) -> Button<Label<Text, Image>>? {
        
        return Button (role: .destructive, action: {
            
            WatchlistManager.removeFromWatchList(result: result)
            viewModel.showRemovedAlert = true
            viewModel.listNeedsUpdate = true
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }) {
            Label("Remove", systemImage: "trash")
        }
    }
    
    func constructResult(result: Result) -> some View {
        
        return HStack {
            if let imageURL = result.getResultPosterURL(),
               let url = APIKeys().imageKey + imageURL {
                
                GenericImageView(url: url,
                                 width: 70,
                                 height: 100,
                                 cornerRadius: 10,
                                 showShadow: false)
            }
            
            VStack(alignment: .leading) {
                Text(result.getResultTitle())
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                    .frame(height: 10)
                
                HStack {
                    Text(result.getReleaseDate() + result.getMediaType())
                    Spacer()
                }
                .font(.system(size: 12, weight: .light))
            }
            .foregroundColor(Color(.systemBackground))
            .colorInvert()
            .padding()
        }
        .background(Color(.systemGray5))
        .cornerRadius(10)
        .padding(.init(top: 0, leading: 15, bottom: 0, trailing: 15))
    }
}
