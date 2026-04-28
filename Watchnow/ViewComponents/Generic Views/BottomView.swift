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

    var body: some View {
        Section {
            ScrollableContentView(results: results,
                                  screenType: screenType,
                                  viewModel: viewModel,
                                  viewSection: viewSection,
                                  cardType: .bottom)
            .background(LinearGradient(colors: [.clear, Color(.secondaryBackground).opacity(0.6)], startPoint: .center, endPoint: .bottom))
        } header: {
            SectionHeaderView(
                title: viewSection.cleanTitle,
                icon: viewSection.themeIcon,
                tint: viewSection.themeColor,
                showsPulse: viewSection.isTrending
            )
            .textCase(.none)
        }
    }
}
