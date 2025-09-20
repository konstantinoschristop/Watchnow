//
//  PosterImage.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI
import Kingfisher

struct PosterImage: View {
    var url: URL?
    var width: CGFloat = 350
    var height: CGFloat = 650
    var cornerRadius: CGFloat = 15
    var shadowRadius: CGFloat = 5
    
    var body: some View {
        KFImage.url(url)
            .downsampling(size: CGSize(width: width, height: height))
            .loadImmediately()
            .loadDiskFileSynchronously()
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .fade(duration: 0.25)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .cornerRadius(cornerRadius)
            .shadow(color: .black, radius: shadowRadius)
    }
}
