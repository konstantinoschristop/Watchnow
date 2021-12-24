//
//  ContentDetailsView.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher

enum ScreenTypes {
    case movie
    case serie
}

struct ContentDetailsView: View {
    
    let result: Result
    let screenType: ScreenTypes
    
    
    var body: some View {
        VStack() {
            KFImage.url(URL(string: APIKeys().imageKey + (result.poster_path ?? result.backdrop_path ?? "")!))
            // .placeholder(placeholderImage)
                .downsampling(size: CGSize.init(width: 450, height: 750))
                .loadImmediately()
                .loadDiskFileSynchronously()
                .fromMemoryCacheOrRefresh()
                .cacheOriginalImage()
                .fade(duration: 0.25)
                .onProgress { receivedSize, totalSize in  }
                .onSuccess { result in  }
                .onFailure { error in }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .mask(LinearGradient(gradient: Gradient(colors: [Color.clear, Color.black]), startPoint: .bottom, endPoint: .top))
                .frame(height: 400)
            
            Spacer()
                .frame(height: 70)
            Text((result.title ?? result.name) ?? "")
                .font(.system(size: 25, weight: .heavy))
            Spacer()
        }
        
//        switch screenType {
//        case .movie:
//            // movie details
//        case .serie:
//            // serie details
//        }
      
    }
    
}
