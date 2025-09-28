//
//  MenuFeaturedView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/6/23.
//

import SwiftUI
import Kingfisher

struct MenuFeaturedView<Content: View>: View {
    var imageURL: URL
    var overlayContent: Content
    @Binding var showNavBar: Bool

    var body: some View {
        
        KFImage.url(imageURL)
            .placeholder {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .loadImmediately()
            .loadDiskFileSynchronously()
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .fade(duration: 0.25)
            .resizable()
            .stretchy()
            .overlay {
                overlayContent
            }
            .frame(height: (UIScreen.main.bounds.size.height) - (UIScreen.main.bounds.size.height / 2.5))
    }
}

