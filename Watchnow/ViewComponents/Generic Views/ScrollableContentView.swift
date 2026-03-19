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
    @State private var thresholdReached: Bool = false
    
    var body: some View {
        
        StretchingActionScrollView(onTriggered: {
            Task { @MainActor in
                performFeedback.toggle()
                viewModel.loadMoreContent(section: viewSection)
            }
        },
                                   onThresholdReached: { thresholdReached in
            self.thresholdReached = thresholdReached
        },
                                   content: getContent)
        .frame(height: cardType == .bottom ? 250 : 180)
        .sensoryFeedback(.success, trigger: performFeedback)
    }
    
    func getContent() -> some View {
        HStack(alignment: .top,
               spacing: cardType == .bottom ? 5 : -15) {
            
            let height: CGFloat = cardType == .bottom ? 200 : 180
            let width: CGFloat = cardType == .bottom ? 130 : 200
            
            Spacer().frame(width: cardType == .bottom ? 10 : 60)
            
            ForEach(results, id: \.self) { movie in
                GeometryReader { proxy in
                    let scale = Scale.getScale(
                        proxy: proxy,
                        scaleType: cardType == .bottom ? .vertical : .horizontal
                    )
                    
                    Group {
                        if cardType == .bottom {
                            BottomCard(content: movie,
                                       screenType: screenType)
                        } else {
                            TopCard(content: movie,
                                    screenType: screenType)
                        }
                    }
                    .frame(width: width, height: height)
                    .scaleEffect(.init(width: scale, height: scale))
                    .animation(.easeOut, value: 1)
                    .padding(.vertical)
                }
                .frame(width: cardType == .bottom ? 150 : 250,
                       height: cardType == .bottom ? 250 : 200)
                .background(Color.clear)
                .padding(.vertical, 30)
            }
        }
               .safeAreaInset(edge: .trailing, alignment: .center) {
                   if viewModel.canLoadMoreContent(section: viewSection) {
                       LoadMoreButtonView(thresholdReached: thresholdReached)
                           .frame(width: 50, height: 50)
                   }
               }
    }
}
