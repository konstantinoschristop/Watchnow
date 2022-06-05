//
//  SimilarsView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 5/6/22.
//

import SwiftUI
import Kingfisher

struct SimilarsView: View {
    
    let content: [Result]
    let screenType: ScreenTypes
    
    var body: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(content, id: \.self) { content in
                    ZStack {
                        NavigationLink {
                            ContentDetailsView(result: content, screenType: screenType)
                        } label: {
                            VStack {
                                KFImage.url(URL(string: APIKeys().imageKey + (content.poster_path ?? "")))
                                    .downsampling(size: CGSize.init(width: 250, height: 350))
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
                                    .cornerRadius(15)
                                    .shadow(color: .black, radius: 5)
                                    .frame(width: 150, height: 200, alignment: .center)
                                Text((content.title ?? content.name) ?? "- -" )
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundColor(Color(.systemBackground))
                                    .colorInvert()
                                    .frame(width: 150, height: 50, alignment: .top)
                            }
                        }
                        HStack {
                            (Text(Image(systemName: "star.fill")) + Text(" ") + Text(String(format: "%.1f", content.vote_average ?? "-"))
                                .foregroundColor(.gray))
                            .font(.system(size: 10, weight: .regular))
                            .padding(.vertical, 5)
                            .padding(.horizontal, 9)
                            .background(Color.white)
                            .foregroundColor(.orange)
                            .cornerRadius(10)
                            .offset(x: 60 , y: -120)
                        }
                    }
                    .frame(height: 270)
                }
            }
        }
    }
}
