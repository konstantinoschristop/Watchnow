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
    @StateObject var detailsViewModel: ContentDetailsViewModel
    
    @State var videoPresented = false
    
    var body: some View {
        
        Group {
            createImageView()
        }
        .sheet(isPresented: $videoPresented) {
            WebView(videoURL: detailsViewModel.videos?.getVideoURL())
                .ignoresSafeArea()
        }
    }
    
    fileprivate func createImageView() -> some View {
        return GeometryReader { proxy  in
            let minY = proxy.frame(in: .named("SCROLL")).minY
            let size = proxy.size
            let height = size.height + minY
            
            KFImage.url(URL(string: APIKeys().imageKey + result.getResultPosterURL()))
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
                    ZStack(alignment: .bottom) {
                        LinearGradient(colors: [.clear,
                                                .black.opacity(0.6)],
                                       startPoint: .center,
                                       endPoint: .bottom)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text((result.title ?? result.name) ?? "")
                                    .font(.custom("AvenirNext-Bold", size: 25))
                                    .foregroundColor(.white)
                                Spacer()
                                
                                if detailsViewModel.videos?.getVideoURL() != nil {
                                    VStack {
                                        Button(action: {
                                            videoPresented.toggle()
                                        }) {
                                            Image(systemName: "play.fill")
                                                .imageScale(SwiftUI.Image.Scale.large)
                                                .foregroundColor(.red)
                                        }
                                        Spacer()
                                            .frame(height: 12)
                                        Text("Watch Trailer")
                                            .font(.custom("AvenirNext-Bold", size: 12))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .shadow(color: .black, radius: 3)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                       
                    }
                    .blur(radius: height < 150 ? 10 : 0)
                }
                .cornerRadius(1)
                .offset(y: -minY)
                .onChange(of: height) { newValue in
                    self.detailsViewModel.imageHeight = Float(newValue)
                }
        }
        .frame(height: (UIScreen.main.bounds.size.height) - (UIScreen.main.bounds.size.height / 2.7))
    }
}
