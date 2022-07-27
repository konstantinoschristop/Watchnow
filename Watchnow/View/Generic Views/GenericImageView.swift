//
//  GenericImageView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 5/6/22.
//

import SwiftUI
import Kingfisher

struct GenericImageView: View {
    
    let url: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let showShadow: Bool
    
    init(url: String,
         width: CGFloat,
         height: CGFloat,
         cornerRadius: CGFloat = 0,
         showShadow: Bool = true) {
        
        self.url = url
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.showShadow = showShadow
    }
    
    var body: some View {
        KFImage.url(URL(string: url.replacingOccurrences(of: "/https", with: "https")))
            .downsampling(size: CGSize.init(width: width * 2, height: height * 2))
            .loadImmediately()
            .loadDiskFileSynchronously()
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .fade(duration: 0.25)
            .onProgress { receivedSize, totalSize in  }
            .onSuccess { result in  }
            .onFailure { error in }
            .resizable()
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .shadow(color: showShadow ? .gray : .clear, radius: 5)
    }
}
