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
    
    var body: some View {
        VStack(spacing: 0) {
            SectionHeaderView(title: viewTitle)
            
            ScrollableContentView(results: results, screenType: screenType, viewModel: viewModel, viewSection: viewSection, cardType: .top)
        }
        .background(LinearGradient(colors: [.clear, Color(.systemGray5).opacity(0.6)], startPoint: .center, endPoint: .bottom))
    }
}
