//
//  BottomView.swift
//  Watchnow
//
//  Created by k.christopoulos on 27/11/21.
//

import SwiftUI

// MARK: - BottomView (Main View)
struct BottomView: View {

    var results: [Result]
    var viewTitle: String
    var screenType: ScreenTypes
    var viewModel: BaseViewModelProtocol
    var viewSection: ViewSections
    var adSlot: Int? = nil
    var namespace: Namespace.ID
    var onSelect: (Result) -> Void

    var body: some View {
        // A plain stack, not a `Section`. In the `List` the feed scrolls on,
        // a section header is pinned to the top while its rows pass under it
        // and is restyled to the list's secondary grey — neither of which the
        // feed wants. Stacked like this the header scrolls with its row and
        // keeps its own typography.
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(
                title: viewSection.cleanTitle,
                icon: viewSection.themeIcon,
                tint: viewSection.themeColor,
                showsPulse: viewSection.isTrending
            )

            ScrollableContentView(results: results,
                                  screenType: screenType,
                                  viewModel: viewModel,
                                  viewSection: viewSection,
                                  cardType: .bottom,
                                  namespace: namespace,
                                  onSelect: onSelect,
                                  adSlot: adSlot)
            .background(LinearGradient(colors: [.clear, Color(.secondaryBackground).opacity(0.6)], startPoint: .center, endPoint: .bottom))
        }
    }
}
