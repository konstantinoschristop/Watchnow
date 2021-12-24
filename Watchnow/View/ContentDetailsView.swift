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
        VStack {
            KFImage.url(URL(string: APIKeys().imageKey + (result.poster_path ?? "")!))
            // .placeholder(placeholderImage)
                .downsampling(size: CGSize.init(width: 250, height: 450))
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
                .ignoresSafeArea()
            Spacer()
        }
       
        
          //  .navigationTitle((result.title ?? result.name) ?? "")
    }
    
}
