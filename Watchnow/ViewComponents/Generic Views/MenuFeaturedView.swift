//
//  MenuFeaturedView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/6/23.
//

import SwiftUI
import Kingfisher

struct MenuFeaturedView<Content: View>: View {
    
    var content: Result
    var overlayContent: Content
    @Binding var showNavBar: Bool
    
    var body: some View {
        GeometryReader { proxy  in
            let minY = proxy.frame(in: .named("SCROLL")).minY
            let size = proxy.size
            let height = size.height + minY
            
            KFImage.url(URL(string: APIKeys().imageKey + content.getResultPosterURL()))
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
                        withAnimation(.easeInOut) {
                            let range = 450...
                            let newMinY = Int(newValue)
                            showNavBar = range.contains(newMinY) || showNavBar && range.contains(newMinY + 100)
                        }
                    }
                }
        }
        .frame(height: (UIScreen.main.bounds.size.height) - (UIScreen.main.bounds.size.height / 2.7))
    }
}
