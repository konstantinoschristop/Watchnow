//
//  TopView.swift
//  Watchnow
//
//  Created by k.christopoulos on 27/11/21.
//

import SwiftUI

struct TopView: View {
    
    var results: [Result]
    var viewTitle: String
    var screenType: ScreenTypes
    
    var body: some View {
        VStack(spacing: -5) {
            HStack {
                Text(viewTitle)
                    .font(.system(size: 25, weight: .heavy))
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: -15) {
                    Spacer()
                        .frame(width: 60)
                    
                    ForEach(results, id: \.self) { movie in
                       
                        GeometryReader { proxy in
                            let scale = Scale.getScale(proxy: proxy, scaleType: .horizontal)
                            VStack {
                                TopCard(title: movie.title ?? movie.name, backdropPath: movie.backdrop_path ?? movie.poster_path, rating: movie.vote_average, result: movie, screenType: screenType)
                                           .frame(width: 300, height: 200, alignment: .center)
                            }
                            .scaleEffect(.init(width: scale, height: scale))
                            .animation(.easeOut, value: 1)
                            .padding(.vertical)
                        }
                        .frame(width: 350, height: 210)
                        .background(Color.clear)
                        .padding(.vertical, 30)
                    }
                }
            }
        }
    }
}


