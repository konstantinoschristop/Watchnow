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
    
    
    fileprivate func Details() -> some View {
        return VStack(alignment: .center) {
            Text((result.title ?? result.name) ?? "")
                .font(.custom("AvenirNext-Bold", size: 40))
                .lineLimit(nil)
            Spacer()
                .frame(height: 5)
            HStack {
                if let rating = result.vote_average {
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                    Text(String(format: "%.1f", rating))
                    Text("•")
                }
                if let allRatings = result.vote_count {
                    Text(String(allRatings) + " ratings •")
                }
                if let releaseData = result.release_date?.dropLast(6) {
                    Text("Released: " + releaseData)
                }
            }
            .font(.custom("AvenirNext-Regular", size: 15))
            .foregroundColor(.gray)
            
            Spacer()
                .frame(height: 20)
            
            if let overview = result.overview {
                Text(overview)
            }
        }
        .padding(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
    }
    
    var body: some View {
        
        ScrollView {
            GeometryReader { geometry in
                ZStack {
                    if geometry.frame(in: .global).minY <= 0 {
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
                            .ignoresSafeArea()
                            .mask(LinearGradient(gradient: Gradient(colors: [Color.clear, Color.black]), startPoint: .bottom, endPoint: .center))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(y: geometry.frame(in: .global).minY/9)
                            .clipped()
                    } else {
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
                            .ignoresSafeArea()
                            .mask(LinearGradient(gradient: Gradient(colors: [Color.clear, Color.black]), startPoint: .bottom, endPoint: .center))
                            .frame(width: geometry.size.width, height: geometry.size.height + geometry.frame(in: .global).minY)
                            .clipped()
                            .offset(y: -geometry.frame(in: .global).minY)
                    }
                }
            }
            .frame(height: 600)
            .padding(.top, -10)
            VStack {
                Spacer(minLength: -20)
                Details()
                Details()
                Details()
            }

        }
        .edgesIgnoringSafeArea(.all)
        
        
        //        switch screenType {
        //        case .movie:
        //            // movie details
        //        case .serie:
        //            // serie details
        //        }
        
    }
    
}
