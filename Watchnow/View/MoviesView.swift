//
//  MoviesView.swift
//  Watchnow
//
//  Created by k.christopoulos on 1/8/21.
//

import SwiftUI
import URLImage
import ACarousel

struct MoviesView: View {
    
    @State var upcomingModel: UpcomingMoviesViewModel
  //  @State var upcomingImages: [UIImage]
    
    @State var popularModel: PopularMoviesViewModel
   // @State var popularImages: [UIImage]
    
    @State var hasNotch = false
    
    func getScale(proxy: GeometryProxy) -> CGFloat {
        let midPoint: CGFloat = 120
        
        let viewFrame = proxy.frame(in: CoordinateSpace.global)
        
        var scale: CGFloat = 1.0
        let deltaXAnimationThreshold: CGFloat = 100
        
        let diffFromCenter = abs(midPoint - viewFrame.origin.x - deltaXAnimationThreshold / 2)
        if diffFromCenter < deltaXAnimationThreshold {
            scale = 1 + (deltaXAnimationThreshold - diffFromCenter) / 400
        }
        
        return scale
    }
    
    var body: some View {
        
        VStack(spacing: -10) {
            HStack {
                Text("Upcoming Movies")
                    .font(.system(size: 25, weight: .heavy))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: -15) {
                    Spacer()
                        .frame(width: 60)
                    ForEach(0 ..< upcomingModel.movieTitles.count) { index in
                       
                        GeometryReader { proxy in
                            let scale = getScale(proxy: proxy)
                            VStack {
                        NavigationLink(destination: ContentDetailsView(text: upcomingModel.movieTitles[index]),
                                       label: {
                                        TopCard(title: upcomingModel.movieTitles[index], backdropURL: upcomingModel.movieBackdrops[index], rating: upcomingModel.movieRatings[index])
                                           .frame(width: 300, height: 200, alignment: .center)
                                       })
                            }
                            .scaleEffect(.init(width: scale, height: scale))
                            .animation(.easeOut(duration: 1))
                            
                            .padding(.vertical)
                        }
                        .frame(width: 350, height: 210)
                        .background(Color.clear)
                        .padding(.vertical, 30)
                        
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Text("Popular Movies")
                    .font(.system(size: 25, weight: .heavy))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 5) {
                    Spacer()
                        .frame(width: 10)
                    ForEach(0 ..< popularModel.movieTitles.count) { index in
                       
                        GeometryReader { proxy in
                            let scale = getScale(proxy: proxy)
                            VStack {
                        NavigationLink(destination: ContentDetailsView(text: popularModel.movieTitles[index]),
                                       label: {
                                        BottomCard(title: popularModel.movieTitles[index], posterURL: popularModel.moviePosters[index], rating: popularModel.movieRatings[index])
                                          .frame(width: 200, height: 300, alignment: .center)
                                           
                                       })
                            }
                            .scaleEffect(.init(width: scale, height: scale))
                            .animation(.easeOut(duration: 1))
                            
                            .padding(.vertical)
                        }
                        .frame(width: 200, height: 330)
                        .background(Color.clear)
                        .padding(.vertical, 30)
                        
                    }
                }
            }
            
            
        }
    }
}
