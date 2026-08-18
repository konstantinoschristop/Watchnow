//
//  SimilarsView.swift
//  Watchnow
//
//  Horizontal row used by "More like this" / "Similar" / "Collection" on
//  the details screen. Uses `BottomCard` — the same card component the
//  home screen's "Popular", "Most Watched" etc. rows paint with — so
//  cards look identical across the two surfaces and users learn one
//  card grammar instead of two.
//
//  Unlike the home screen, cards don't scale with scroll position.
//  `ScrollableContentView` does a `Scale.getScale` centre-weighted
//  zoom in the home rows, which feels great as the primary gesture
//  but fights the details screen's outer vertical scroll (the details
//  screen is already scrolling; a per-card horizontal scale would read
//  as jitter rather than polish).
//

import SwiftUI

struct SimilarsView: View {

    let content: [Result]
    let screenType: ScreenTypes
    /// Kept for API parity with the previous call site; unused because
    /// `BottomCard` drives its own zoom-navigation namespace internally.
    /// Prefixed with `_` to document the intent without breaking callers.
    var namespace: Namespace.ID

    // Matches the home-screen `BottomCard` footprint so "Similar" cards
    // and "Popular Movies" cards sit at the exact same visual weight.
    private let cardWidth: CGFloat = 130
    private let cardHeight: CGFloat = 230
    private let cardSpacing: CGFloat = 10

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: cardSpacing) {
                ForEach(Array(content.enumerated()), id: \.element) { index, item in
                    // One native ad, slotted in like another poster card.
                    if index == 3 {
                        NativeAdCard(posterHeight: 175,
                                     cardWidth: cardWidth,
                                     cardHeight: cardHeight)
                    }
                    BottomCard(content: item, screenType: screenType)
                        .frame(width: cardWidth, height: cardHeight, alignment: .top)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
