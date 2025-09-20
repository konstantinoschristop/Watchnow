//
//  BottomCard.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher

// MARK: - BottomCard Component
struct BottomCard: View {
    var content: Result
    var screenType: ScreenTypes
    @Environment(\.colorScheme) var colorScheme
    
    init(content: Result, screenType: ScreenTypes) {
        self.screenType = screenType
        self.content = content
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .center) {
                NavigationLink {
                    let model = ContentDetailsModel(screenType: screenType, result: content)
                    let vm = ContentDetailsViewModel(model: model)
                    ContentDetailsView(detailsViewModel: vm)
                } label: {
                    VStack {
                        PosterImage(url: content.getPosterURL())
                        TitleText(title: content.getResultTitle())
                    }
                }
            }
            
            RatingView(rating: content.vote_average, cardType: .bottom)
        }
    }
}
