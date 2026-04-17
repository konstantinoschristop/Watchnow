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
    @State private var loadMoreProgress: CGFloat = 0

    // Card dimensions. Top cards are a Netflix-style numeral + poster pair:
    // card width ≈ numeral frame (78) + poster (100) - overlap (14) = 164,
    // rounded up to 180 for a touch of right-side breathing room.
    private var cardWidth: CGFloat  { cardType == .bottom ? 130 : 180 }
    private var cardHeight: CGFloat { cardType == .bottom ? 230 : 165 }
    // Slot = card * maxScale (≈1.27 at centre) + a hair of padding so the
    // scaled card never clips. Tight slot widths keep the row from looking
    // airy when most cards sit at scale 1.0.
    private var slotWidth: CGFloat  { cardType == .bottom ? 150 : 232 }
    private var slotHeight: CGFloat { cardType == .bottom ? 295 : 215 }

    var body: some View {
        StretchingActionScrollView(onTriggered: {
            Task { @MainActor in
                performFeedback.toggle()
                viewModel.loadMoreContent(section: viewSection)
            }
        }, onThresholdReached: { thresholdReached in
            self.thresholdReached = thresholdReached
        }, onProgress: { progress in
            self.loadMoreProgress = progress
        }, content: getContent)
        .frame(height: slotHeight)
        .sensoryFeedback(.success, trigger: performFeedback)
    }

    func getContent() -> some View {
        HStack(alignment: .top,
               spacing: cardType == .bottom ? 5 : 0) {

            Spacer().frame(width: cardType == .bottom ? 10 : 20)

            // `enumerated()` gives us the 1-based rank to pass into TopCard.
            // `id: \.element` keeps the identity stable across paginated
            // reloads (Result is Hashable) instead of tying it to the list
            // position.
            ForEach(Array(results.enumerated()), id: \.element) { index, movie in
                GeometryReader { proxy in
                    let scale = Scale.getScale(
                        proxy: proxy,
                        scaleType: cardType == .bottom ? .vertical : .horizontal
                    )
                    Group {
                        if cardType == .bottom {
                            BottomCard(content: movie, screenType: screenType)
                        } else {
                            TopCard(content: movie, screenType: screenType, rank: index + 1)
                        }
                    }
                    .frame(width: cardWidth, height: cardHeight)
                    .scaleEffect(.init(width: scale, height: scale))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
                .frame(width: slotWidth, height: slotHeight)

                if results.last == movie,
                   viewModel.canLoadMoreContent(section: viewSection) {
                    LoadMoreButtonView(progress: loadMoreProgress)
                }
            }
        }
    }
}
