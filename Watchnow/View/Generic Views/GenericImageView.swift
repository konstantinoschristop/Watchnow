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
    
    var body: some View {
        KFImage.url(URL(string: url.replacingOccurrences(of: "/https", with: "https")))
            .downsampling(size: CGSize.init(width: width, height: height))
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
            .shadow(color: .gray, radius: 5)
    }
}
