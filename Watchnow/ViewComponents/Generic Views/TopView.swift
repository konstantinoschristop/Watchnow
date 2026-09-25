//
//  TopView.swift
//  Watchnow
//
//  Created by k.christopoulos on 27/11/21.
//

import SwiftUI

// MARK: - TopView (Main View)
struct TopView: View {
    
    var results: [Result]
    var viewTitle: String
    var screenType: ScreenTypes
    var viewModel: BaseViewModelProtocol
    var viewSection: ViewSections
    var namespace: Namespace.ID
    var onSelect: (Result) -> Void

    var body: some View {
        Section {
            ScrollableContentView(results: results,
                                  screenType: screenType,
                                  viewModel: viewModel,
                                  viewSection: viewSection,
                                  cardType: .top,
                                  namespace: namespace,
                                  onSelect: onSelect)
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
