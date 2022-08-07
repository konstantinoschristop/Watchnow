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
            Button (role: .destructive, action: {
                WatchlistManager.removeFromWatchList(result: result)
                
                if let vmResults = (viewModel as? WatchlistViewModel)?.results,
                   let index = vmResults.firstIndex(of: result) {
                    withAnimation {
                        (viewModel as? WatchlistViewModel)?.results?.remove(at: index)
                        (viewModel as? WatchlistViewModel)?.refreshDataIfNeeded()
                        (viewModel as? WatchlistViewModel)?.showAlert = true
                    }
                }
            }) {
                Label("Remove", systemImage: "bookmark.slash.fill")
            }
        }
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
