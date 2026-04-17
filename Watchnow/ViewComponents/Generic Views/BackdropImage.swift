//
//  BackdropImage.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI
import Kingfisher

// MARK: - BackdropImage Component
struct BackdropImage: View {
    var url: URL?

    var body: some View {
        KFImage.url(url)
            .downsampling(size: CGSize(width: 650, height: 350))
            .loadImmediately()
            .loadDiskFileSynchronously()
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .fade(duration: 0.25)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .cornerRadius(15)
        .shadow(color: .black, radius: 5)
    }
}
