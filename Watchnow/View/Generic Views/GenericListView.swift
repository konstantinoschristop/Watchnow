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
    @State var viewModel: BaseSwipeActionsProtocol
    
    var body: some View {
        
        ForEach(Array(results.enumerated()), id: \.element) { index, result in
            NavigationLink {
                switch result.getMediaType() {
                case "Actor":
                    if let personID = result.id {
                        PersonView(personID: personID)
                    }
                default:
                    ContentDetailsView(result: result, screenType: result.media_type == "movie" ? .movie : .tv)
                }
            }
            label: {
                VStack(spacing: 2) {
                    self.constructResult(result: result)
                    Divider()
                }
            }
            .listRowSeparatorTint(.clear)
            .listRowBackground(Color(.systemGray6))
            .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
            .swipeActions(allowsFullSwipe: true, content: {
                if result.getMediaType() == "Actor" {
                    EmptyView()
                } else {
                    switch WatchlistManager.existsInWatchList(result: result) {
                    case true:
                        self.contructRemoveSwipeAction(result: result)
                            .tint(.red)
                    case false:
                        self.contructAddSwipeAction(result: result)
                            .tint(.green)
                    }
                }
            })
        }
    }
    
    @MainActor
    func contructAddSwipeAction(result: Result) -> Button<Label<Text, Image>>? {
        
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
    func contructRemoveSwipeAction(result: Result) -> Button<Label<Text, Image>>? {
        
        return Button (action: {
            withAnimation {
                WatchlistManager.removeFromWatchList(result: result)
                viewModel.showRemovedAlert = true
                viewModel.listNeedsUpdate = true
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
        }) {
            Label("Remove", systemImage: "trash")
        }
    }
    
    func constructResult(result: Result) -> some View {
        
        return HStack(alignment: .top) {
            let imageURL = result.getResultPosterURL()
            let url = APIKeys().imageKey + imageURL
            
            GenericImageView(url: url,
                             width: 60,
                             height: 80,
                             cornerRadius: 5,
                             showShadow: false)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(result.getResultTitle())
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 2) {
                    Text(result.getReleaseDate())
                    Text(result.getMediaType())
                    Spacer()
                }
                .font(.system(size: 14, weight: .light))
            }
            .foregroundColor(Color(.systemBackground))
            .colorInvert()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
