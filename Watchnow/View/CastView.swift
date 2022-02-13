//
//  CastView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/2/22.
//

import SwiftUI
import Kingfisher

struct CastView: View {
    
    let cast: [Cast]
    
    var body: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(cast, id: \.self) { cast in
                    VStack {
                        KFImage.url(URL(string: APIKeys().imageCastKey + (cast.profile_path ?? "")))
                            .downsampling(size: CGSize.init(width: 200, height: 200))
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
                            .cornerRadius(6)
                            .shadow(color: .black, radius: 5)
                            .frame(width: 80, height: 120)
                        Text((cast.name ?? cast.original_name) ?? "")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(Color(.systemBackground))
                            .colorInvert()
                            .frame(width: 80, height: 30)
                    }
                }
            }
        }
    }
}
