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
        GeometryReader { proxy  in
            let minY = proxy.frame(in: .named("SCROLL")).minY
            let size = proxy.size
            let height = size.height + minY
            
            KFImage.url(imageURL)
                .placeholder { ProgressView() }
                .loadImmediately()
                .loadDiskFileSynchronously()
                .fromMemoryCacheOrRefresh()
                .cacheOriginalImage()
                .fade(duration: 0.25)
                .onProgress { receivedSize, totalSize in  }
                .onSuccess { result in }
                .onFailure { error in }
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: height > 0 ? height : 0)
                .overlay {
                    overlayContent
                }
                .cornerRadius(1)
                .offset(y: -minY)
                .onChange(of: -minY) { newValue in
                    DispatchQueue.main.async {
                        withAnimation(.bouncy) {
                            let range = 420...
                            let newMinY = Int(newValue)
                            if range.contains(newMinY) || showNavBar && range.contains(newMinY + 80) {
                                if showNavBar == false {
                                    showNavBar = true
                                }
                            } else {
                                if showNavBar == true {
                                    showNavBar = false
                                }
                            }
                        }
                    }
                }
        }
        .frame(height: (UIScreen.main.bounds.size.height) - (UIScreen.main.bounds.size.height / 2.7))
    }
}
