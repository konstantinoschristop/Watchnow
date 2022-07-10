//
//  TopCard.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher

struct TopCard: View {
    
    var content: Result
    var screenType: ScreenTypes
    @State var isPresented = false
    
    init(content: Result, screenType: ScreenTypes) {
        
        self.screenType = screenType
        self.content = content
    }
    
    var body: some View {
        
        ZStack {
            VStack(alignment: .leading) {
                NavigationLink {
                    ContentDetailsView(result: content, screenType: screenType)
                } label: {
                    VStack {
                        KFImage.url(URL(string: APIKeys().imageKey + (content.backdrop_path ?? "")))
                            .downsampling(size: CGSize.init(width: 650, height: 350))
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
                        Text(content.getResultTitle())
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(Color(.systemBackground))
                            .colorInvert()
                    }
                }
            }
            
            HStack {
                (Text(Image(systemName: "star.fill")) + Text(" ") + Text(String(format: "%.1f", content.vote_average ?? "-"))
                    .foregroundColor(.gray))
                    .font(.system(size: 14, weight: .regular))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 9)
                    .background(Color(.systemGray5))
                    .foregroundColor(.orange)
                    .cornerRadius(10)
                    .offset(x: 120 , y: -100)
            }
        }
    }
}
