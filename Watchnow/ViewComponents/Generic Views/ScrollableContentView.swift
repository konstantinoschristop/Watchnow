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
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: cardType == .bottom ? 5 : -15) {
                Spacer().frame(width: cardType == .bottom ? 10 : 60)
                
                ForEach(results, id: \.self) { movie in
                    GeometryReader { proxy in
                        let scale = Scale.getScale(proxy: proxy, scaleType: cardType == .bottom ? .vertical : .horizontal)
                        VStack {
                            if cardType == .bottom {
                                BottomCard(content: movie, screenType: screenType)
                                    .frame(width: 200, height: 300, alignment: .center)
                            } else {
                                TopCard(content: movie, screenType: screenType)
                                    .frame(width: 300, height: 200, alignment: .center)
                            }
                        }
                        .scaleEffect(.init(width: scale, height: scale))
                        .animation(.easeOut, value: 1)
                        .padding(.vertical)
                    }
                    .frame(width: cardType == .bottom ? 200 : 350, height: cardType == .bottom ? 320 : 215)
                    .background(Color.clear)
                    .padding(.vertical, 30)
                    
                    LoadMoreButtonView(results: results, movie: movie, viewModel: viewModel, viewSection: viewSection)
                }
            }
        }
    }
}
