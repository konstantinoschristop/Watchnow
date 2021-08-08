//
//  BottomCard.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher

struct BottomCard: View {
        
        let title: String
        let posterURL: URL
        let rating: Double
     //   let genre: String
        
        var body: some View {
            
            ZStack {
            VStack(alignment: .center) {
                    
                        KFImage.url(self.posterURL)
                         // .placeholder(placeholderImage)
                            .downsampling(size: CGSize.init(width: 200, height: 300))
                            .loadImmediately()
                            .loadDiskFileSynchronously()
                            .fromMemoryCacheOrRefresh()
                            .cacheOriginalImage()
                            .fade(duration: 0.25)
                            .onProgress { receivedSize, totalSize in  }
                            .onSuccess { result in  }
                            .onFailure { error in }
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                
                Text(title)
                    .font(.system(size: 16, weight: .heavy))
                    .multilineTextAlignment(.center)
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
                        .offset(x: 60 , y: -150)
                }
            }
        }
    }

