//
//  BottomCard.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher

struct BottomCard: View {
    
    var title: String = ""
    var posterURL: URL?
    var rating: Double = 0.0
    @Environment(\.colorScheme) var colorScheme
    
    init(title: String?, posterPath: String?, rating: Double?) {
        
        guard let title = title,
              let posterPath = posterPath,
              let rating = rating else {
                  return
              }
        
        self.title = title
        self.posterURL = URL(string: APIKeys().imageKey + posterPath)!
        self.rating = rating
    }
    
    var body: some View {
        
        ZStack {
            VStack(alignment: .center) {
//                NavigationLink(destination: ContentDetailsView(text: self.title),
//                               label: {
                    KFImage.url(self.posterURL)
                    // .placeholder(placeholderImage)
                        .downsampling(size: CGSize.init(width: 250, height: 450))
                        .loadImmediately()
                        .loadDiskFileSynchronously()
                        .fromMemoryCacheOrRefresh()
                        .cacheOriginalImage()
                        .fade(duration: 0.25)
                        .onProgress { receivedSize, totalSize in }
                        .onSuccess { result in  }
                        .onFailure { error in }
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(15)
                        .shadow(color: .black, radius: 5)
          //      })
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

