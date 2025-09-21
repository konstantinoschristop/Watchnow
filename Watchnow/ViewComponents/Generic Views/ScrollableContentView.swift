//
//  ScrollableContentView.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI

// MARK: - Scrollable Content View (Main Content Section)
struct ScrollableContentView: View {
    enum CardType {
        case top
        case bottom
    }
    
    var results: [Result]
    var screenType: ScreenTypes
    var viewModel: BaseViewModelProtocol
    var viewSection: ViewSections
    var cardType: CardType
        
    @State private var performFeedback: Bool = false
    
    var body: some View {
        
        StretchingActionScrollView {
            // Trigger load more
            Task { @MainActor in
                performFeedback.toggle()
                viewModel.loadMoreContent(section: viewSection)
            }
        } content: {
            HStack(alignment: .top,
                   spacing: cardType == .bottom ? 5 : -15) {
                
                Spacer().frame(width: cardType == .bottom ? 10 : 60)
                
                ForEach(results, id: \.self) { movie in
                    GeometryReader { proxy in
                        let scale = Scale.getScale(
                            proxy: proxy,
                            scaleType: cardType == .bottom ? .vertical : .horizontal
                        )
                        VStack {
                            if cardType == .bottom {
                                BottomCard(content: movie,
                                           screenType: screenType)
                                    .frame(width: 200, height: 300)
                            } else {
                                TopCard(content: movie,
                                        screenType: screenType)
                                    .frame(width: 300, height: 200)
                            }
                        }
                        .scaleEffect(.init(width: scale, height: scale))
                        .animation(.easeOut, value: 1)
                        .padding(.vertical)
                    }
                    .frame(width: cardType == .bottom ? 200 : 350,
                           height: cardType == .bottom ? 320 : 215)
                    .background(Color.clear)
                    .padding(.vertical, 30)
                    
                    if results.last == movie {
                        LoadMoreButtonView(results: results,
                                           movie: movie,
                                           viewModel: viewModel,
                                           viewSection: viewSection)
                    }
                    
                }
            }
        }
        .frame(height: cardType == .bottom ? 400 : 250)
        .sensoryFeedback(.success, trigger: performFeedback)
    }
}
