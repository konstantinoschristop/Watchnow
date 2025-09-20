//
//  LoadMoreButtonView.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI

// MARK: - Load More Button View (For Fetching More Content)
struct LoadMoreButtonView: View {
    var results: [Result]
    var movie: Result
    var viewModel: BaseViewModelProtocol
    var viewSection: ViewSections
    
    var body: some View {
        Group {
            if results.last == movie, viewModel.canLoadMoreContent(section: viewSection) {
                Button {
                    viewModel.loadMoreContent(section: viewSection)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.large)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
