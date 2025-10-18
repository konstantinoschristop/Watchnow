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
    var namespace: Namespace.ID
    
    var body: some View {
        
        ForEach(Array(results.enumerated()), id: \.element) { index, result in
            Group {
                if result.getMediaType() == "Actor" {
                    VStack(spacing: 2) {
                        self.constructResult(result: result)
                        Divider()
                    }
                } else {
                    NavigationLink {
                        let screenType: ScreenTypes = result.media_type == "movie" ? .movie : .tv
                        let model = ContentDetailsModel(screenType: screenType, result: result)
                        let vm = ContentDetailsViewModel(model: model)
                        ContentDetailsView(detailsViewModel: vm)
                            .navigationTransition(.zoom(sourceID: result.id, in: namespace))
                    }
                    label: {
                        VStack(spacing: 2) {
                            self.constructResult(result: result)
                            Divider()
                        }
                    }
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }) {
            Label("Remove", systemImage: "trash")
        }
    }
    
    func constructResult(result: Result) -> some View {
        
        return HStack(alignment: .top) {
            let imageURL = result.getResultPosterURL()
            let url = String(describing: imageURL)
            
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
