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
    /// Shared with the cards below and with the details screen they push, so
    /// the zoom transition matches. `BottomCard` used to own a private
    /// namespace and its own `NavigationLink`; it now takes both from its
    /// caller, because a link inside a `List` row draws a disclosure chevron
    /// on the home feed — see `ContentMainView`.
    var namespace: Namespace.ID

    /// The card the user tapped. Local to this row: the details screen it
    /// pushes is just another `ContentDetailsView`.
    @State private var selection: Selection?

    private struct Selection: Identifiable, Hashable {
        let result: Result
        var id: Int { result.id ?? 0 }
    }

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
                    BottomCard(content: item,
                               screenType: screenType,
                               namespace: namespace,
                               onSelect: { selection = Selection(result: $0) })
                        .frame(width: cardWidth, height: cardHeight, alignment: .top)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationDestination(item: $selection) { selected in
            let model = ContentDetailsModel(screenType: screenType, result: selected.result)
            ContentDetailsView(detailsViewModel: ContentDetailsViewModel(model: model))
                .navigationTransition(.zoom(sourceID: selected.id, in: namespace))
        }
    }
}
