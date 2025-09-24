//
//  TopCard.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI

// MARK: - TopCard Component
struct TopCard: View {
    var content: Result
    var screenType: ScreenTypes
    @State var isPresented = false
    @Environment(\.colorScheme) var colorScheme
    @State var isContextMenuSheetVisible = false
    @Namespace private var namespace
    
    init(content: Result, screenType: ScreenTypes) {
        self.screenType = screenType
        self.content = content
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                NavigationLink {
                    let model = ContentDetailsModel(screenType: screenType, result: content)
                    let vm = ContentDetailsViewModel(model: model)
                    ContentDetailsView(detailsViewModel: vm)
                        .navigationTransition(.zoom(sourceID: "", in: namespace))
                } label: {
                    VStack {
                        BackdropImage(url: content.getBackdropURL())
                        TitleText(title: content.getResultTitle())
                    }
                }
            }
            
            RatingView(rating: content.vote_average, cardType: .top)
        }
    }
}
