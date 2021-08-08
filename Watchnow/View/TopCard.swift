//
//  TopCard.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher

struct TopCard: View {
    
    let title: String
    let backdropURL: URL
    let rating: Double
 //   let genre: String
    
    var body: some View {
        
        ZStack {
        VStack(alignment: .leading) {

                    KFImage.url(self.backdropURL)
                     // .placeholder(placeholderImage)
                        .downsampling(size: CGSize.init(width: 250, height: 200))
                        .loadImmediately()
                        .loadDiskFileSynchronously()
                        .fromMemoryCacheOrRefresh()
                        .cacheOriginalImage()
                        .fade(duration: 0.25)
                        .onProgress { receivedSize, totalSize in  }
                        .onSuccess { result in  }
                        .onFailure { error in }
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                        .shadow(radius: 4)
                
            Text(title)
                .font(.system(size: 16, weight: .heavy))
        }
            HStack {
                (Text(Image(systemName: "star.fill")) + Text(" ") + Text(String(format: "%.1f", rating))
                    .foregroundColor(.gray))
                    .font(.system(size: 14, weight: .regular))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 9)
                    .background(Color.white)
                    .foregroundColor(.orange)
                    .cornerRadius(10)
                    .offset(x: 120 , y: -100)
            }
        }
    }
}
