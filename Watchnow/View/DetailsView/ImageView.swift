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
        
        GeometryReader { proxy  in
            let minY = proxy.frame(in: .named("SCROLL")).minY
            let size = proxy.size
            let height = size.height + minY
            
            KFImage.url(URL(string: APIKeys().imageKey + (result.poster_path ?? result.backdrop_path ?? "")!))
               // .downsampling(size: CGSize.init(width: 550, height: 400))
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
                .frame(width: size.width, height: height > 0 ? height : 0 , alignment: .top)
                .navigationBarTitle(height < 130 ? (result.title ?? result.name) ?? "- -" : "")
                .overlay {
                    ZStack(alignment: .bottom) {
                        LinearGradient(colors: [.clear,
                                                .black.opacity(0.8)],
                                       startPoint: .top,
                                       endPoint: .bottom)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text((result.title ?? result.name) ?? "")
                                    .font(.custom("AvenirNext-Bold", size: 25))
                                    .foregroundColor(.white)
                                Spacer()
                                VStack {
                                    Button(action: {
                                        
                                    }) {
                                        Image(systemName: "plus.rectangle.on.rectangle")
                                            .imageScale(.medium)
                                    }
                                    Spacer()
                                        .frame(height: 10)
                                    Text("Wathclist")
                                        .font(.custom("AvenirNext-Bold", size: 12))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .ignoresSafeArea()
                .cornerRadius(1)
                .offset(y: -minY)
        }
        .frame(height: 330)
    }
}
        
//        GeometryReader { geometry in
//
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
//                        .mask(LinearGradient(gradient: Gradient(colors: [Color.clear, Color.black]), startPoint: .bottom, endPoint: .center))
//                        .frame(width: UIScreen.main.bounds.width, height: geometry.frame(in: .global).minY + 450)
//                        .offset(y: -geometry.frame(in: .global).minY)
//
//        }
//        .frame(height: 450)
        
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

