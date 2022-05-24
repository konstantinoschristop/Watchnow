//
//  ImageView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/2/22.
//

import SwiftUI
import Kingfisher

struct ImageView: View {
    
    let result: Result
    
    var body: some View {
        
        GeometryReader { geometry in

                    KFImage.url(URL(string: APIKeys().imageKey + (result.poster_path ?? result.backdrop_path ?? "")!))
                        .downsampling(size: CGSize.init(width: 550, height: 850))
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
                        .mask(LinearGradient(gradient: Gradient(colors: [Color.clear, Color.black]), startPoint: .bottom, endPoint: .center))
                        .frame(width: UIScreen.main.bounds.width, height: geometry.frame(in: .global).minY + 450)
                        .offset(y: -geometry.frame(in: .global).minY)
                        
        }
        .frame(height: 450)
        
//        GeometryReader { geometry in
//            ZStack {
//                if geometry.frame(in: .global).minY <= 0 {
//                    KFImage.url(URL(string: APIKeys().imageKey + (result.poster_path ?? result.backdrop_path ?? "")!))
//                        .downsampling(size: CGSize.init(width: 550, height: 850))
//                        .loadImmediately()
//                        .loadDiskFileSynchronously()
//                        .fromMemoryCacheOrRefresh()
//                        .cacheOriginalImage()
//                        .fade(duration: 0.25)
//                        .onProgress { receivedSize, totalSize in  }
//                        .onSuccess { result in  }
//                        .onFailure { error in }
//                        .resizable()
//                        .aspectRatio(contentMode: .fill)
//                        .ignoresSafeArea()
//                        .frame(width: geometry.size.width, height: 450)
//                        .mask(LinearGradient(gradient: Gradient(colors: [Color.clear, Color.black]), startPoint: .bottom, endPoint: .center))
//                       // .offset(y: -geometry.frame(in: .global).minY/1.5)
//                } else {
//                    KFImage.url(URL(string: APIKeys().imageKey + (result.poster_path ?? result.backdrop_path ?? "")!))
//                        .downsampling(size: CGSize.init(width: 550, height: 850))
//                        .loadImmediately()
//                        .loadDiskFileSynchronously()
//                        .fromMemoryCacheOrRefresh()
//                        .cacheOriginalImage()
//                        .fade(duration: 0.25)
//                        .onProgress { receivedSize, totalSize in  }
//                        .onSuccess { result in  }
//                        .onFailure { error in }
//                        .resizable()
//                        .aspectRatio(contentMode: .fill)
//                        .ignoresSafeArea()
//                        .frame(width: geometry.size.width, height: 450 + geometry.frame(in: .global).minY)
//                    //.offset(y: -geometry.frame(in: .global).minY + 20)
//                        .mask(LinearGradient(gradient: Gradient(colors: [Color.clear, Color.black]), startPoint: .bottom, endPoint: .center))
//                      //  .offset(y: -geometry.frame(in: .global).minY)
//                }
//            }
//        }
//        .frame(height: 450)
    }
}

