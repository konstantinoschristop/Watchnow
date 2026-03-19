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
    @Namespace private var namespace
    
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
                        .navigationTransition(.zoom(sourceID: "", in: namespace))
                } label: {
                    VStack {
                        PosterImage(url: content.getPosterURL())
                            .overlay(alignment: .top, content: {
                                LinearGradient(colors: [.clear,
                                                        .black.opacity(0.6)],
                                               startPoint: .center,
                                               endPoint: .top)
                                .cornerRadius(10)
                            })
                            .overlay(alignment: .topTrailing) {
                                RatingView(rating: content.vote_average)
                            }
                      //  TitleText(title: content.getResultTitle())
                    }
                }
            }
        }
    }
}
