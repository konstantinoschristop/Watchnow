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
    @State private var isLoading: Bool = false
    
    var body: some View {
        
        StretchingActionScrollView(onTriggered: {
            Task { @MainActor in
                performFeedback.toggle()
                isLoading = true
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec
                viewModel.loadMoreContent(section: viewSection)
                isLoading = false
            }
        },
                                   onThresholdReached: { thresholdReached in
            self.thresholdReached = thresholdReached
        },
                                   content: getContent)
        .frame(height: cardType == .bottom ? 400 : 250)
        .sensoryFeedback(.success, trigger: performFeedback)
    }
    
    func getContent() -> some View {
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
                
                if results.last == movie,
                   viewModel.canLoadMoreContent(section: viewSection) {
                    if isLoading {
                        ProgressView()
                            .frame(width: 30, height: 30)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal)
                    } else {
                        LoadMoreButtonView(thresholdReached: thresholdReached)
                    }
                }
            }
        }
    }
}
