//
//  TopCard.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher

struct TopCard: View {
    
    var title: String = ""
    var backdropURL: URL?
    var rating: Double = 0.0
    var result: Result
    var screenType: ScreenTypes
    //   let genre: String
    
    init(title: String?, backdropPath: String?, rating: Double?, result: Result, screenType: ScreenTypes) {
        
        self.screenType = screenType
        self.result = result
        
        guard let title = title,
              let backdropPath = backdropPath,
              let rating = rating else {
                  return
              }
        
        self.title = title
        self.backdropURL = URL(string: APIKeys().imageKey + backdropPath)!
        self.rating = rating
    }
    
    var body: some View {
        
        ZStack {
            VStack(alignment: .leading) {
                NavigationLink(destination: ContentDetailsView(result: result, screenType: screenType),
                               label: {
                    KFImage.url(self.backdropURL)
                    // .placeholder(placeholderImage)
                        .downsampling(size: CGSize.init(width: 450, height: 250))
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
                        .cornerRadius(15)
                        .shadow(color: .black, radius: 5)
                })
                
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
