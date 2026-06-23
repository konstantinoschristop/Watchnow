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
    /// Index at which to slot a native ad card into the row (nil = none).
    /// Only honoured for `.bottom` rows so it matches the poster-card style.
    var adSlot: Int? = nil

    @State private var performFeedback: Bool = false
    @State private var thresholdReached: Bool = false
    /// Observable so `LoadMoreButtonView` can re-render *during* the
    /// user's overscroll pull. A plain `@State CGFloat` would freeze
    /// at 0 because StretchingActionScrollView buffers parent updates
    /// while the user is dragging — see LoadMoreButtonView's header.
    @StateObject private var loadMoreProgress = LoadMoreProgress()

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
            self.loadMoreProgress.value = progress
        }, content: getContent)
        .frame(height: slotHeight)
        .sensoryFeedback(.success, trigger: performFeedback)
    }

    func getContent() -> some View {
        // Captured once in the SwiftUI body (main-actor context) so the
        // visualEffect closure can reference it without a main-actor call.
        let screenHalfWidth = UIScreen.main.bounds.width / 2
        let scaleType: Scale.ScaleTypes = cardType == .bottom ? .vertical : .horizontal

        return HStack(alignment: .top,
               spacing: cardType == .bottom ? 5 : 0) {

            Spacer().frame(width: cardType == .bottom ? 10 : 20)

            ForEach(Array(results.enumerated()), id: \.element) { index, movie in
                // Native ad card, slotted in like just another poster.
                if cardType == .bottom, let adSlot, index == adSlot {
                    adCardSlot
                }

                cardSlot(for: movie, index: index,
                         screenHalfWidth: screenHalfWidth,
                         scaleType: scaleType)

                if results.last == movie,
                   viewModel.canLoadMoreContent(section: viewSection) {
                    LoadMoreButtonView(tracker: loadMoreProgress)
                }
            }
        }
    }

    /// The native ad framed exactly like a `.bottom` poster slot so it reads
    /// as part of the scroll. Poster height matches `BottomCard` (175).
    private var adCardSlot: some View {
        NativeAdCard(posterHeight: 175)
            .frame(width: cardWidth, height: cardHeight)
            .frame(width: slotWidth, height: slotHeight, alignment: .top)
    }

    /// Card slot with a scale effect that magnifies the card nearest the
    /// screen centre. On iOS 17+ this runs via `visualEffect` — a
    /// display-layer pass that never triggers SwiftUI layout, so scrolling
    /// stays smooth regardless of how many cards are in the row. Pre-iOS 17
    /// falls back to GeometryReader (the original approach).
    @ViewBuilder
    private func cardSlot(for movie: Result,
                          index: Int,
                          screenHalfWidth: CGFloat,
                          scaleType: Scale.ScaleTypes) -> some View {
        if #available(iOS 17, *) {
            cardContent(for: movie, index: index)
                .frame(width: cardWidth, height: cardHeight)
                .visualEffect { content, geometry in
                    let diff = abs(screenHalfWidth - geometry.frame(in: .global).midX)
                    let threshold: CGFloat = scaleType == .vertical ? 150 : 160
                    let scale = diff < threshold ? 1.0 + (threshold - diff) / 600.0 : 1.0
                    return content.scaleEffect(scale)
                }
                .frame(width: slotWidth, height: slotHeight)
        } else {
            GeometryReader { proxy in
                cardContent(for: movie, index: index)
                    .frame(width: cardWidth, height: cardHeight)
                    .scaleEffect(Scale.getScale(proxy: proxy, scaleType: scaleType))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .frame(width: slotWidth, height: slotHeight)
        }
    }

    @ViewBuilder
    private func cardContent(for movie: Result, index: Int) -> some View {
        if cardType == .bottom {
            BottomCard(content: movie, screenType: screenType)
        } else {
            TopCard(content: movie, screenType: screenType, rank: index + 1)
        }
    }
}
