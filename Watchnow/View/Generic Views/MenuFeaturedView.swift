//
//  MenuFeaturedView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/6/23.
//

import SwiftUI
import Kingfisher

struct MenuFeaturedView: View {
    
    var content: Result
    var heightChanged: (CGFloat) -> Void
    
    var body: some View {
        GeometryReader { proxy  in
            let minY = proxy.frame(in: .named("SCROLL")).minY
            let size = proxy.size
            let height = size.height + minY
            
            KFImage.url(URL(string: APIKeys().imageKey + content.getResultPosterURL()))
                .placeholder { ProgressView() }
                .loadImmediately()
                .loadDiskFileSynchronously()
                .fromMemoryCacheOrRefresh()
                .cacheOriginalImage()
                .fade(duration: 0.25)
                .onProgress { receivedSize, totalSize in  }
                .onSuccess { result in }
                .onFailure { error in }
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: height > 0 ? height : 0)
                .overlay {
                    ZStack {
                        LinearGradient(colors: [.clear,
                                                .black.opacity(0.6)],
                                       startPoint: .center,
                                       endPoint: .bottom)
                        
                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, maxHeight: 120)
                                .blur(radius: 20)
                                .opacity(0.5)
                            
                            VStack(alignment: .center, spacing: 3) {
                                Text("Featured Now")
                                    .font(.custom("AvenirNext-Regular", size: 20))
                                
                                Text(content.getResultTitle())
                                    .font(.custom("AvenirNext-Bold", size: 25))
                                    .multilineTextAlignment(.center)
                                
                                HStack {
                                    Text(content.getReleaseDate(addSeparator: false))
                                    Text(" | ")
                                    HStack(spacing: 5) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.orange)
                                        Text(String(format: "%.1f", content.vote_average ?? "-"))
                                    }
                                }
                                .font(.custom("AvenirNext-Regular", size: 18))
                            }
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 3)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding()
                        }
                    }
                }
                .cornerRadius(1)
                .offset(y: -minY)
                .onChange(of: height) { _ in
                    heightChanged(height)
                }
        }
        .frame(height: (UIScreen.main.bounds.size.height) - (UIScreen.main.bounds.size.height / 2.7))
    }
}
