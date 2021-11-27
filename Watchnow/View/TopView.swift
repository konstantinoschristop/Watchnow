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
    
    var body: some View {
       
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
                        let scale = Scale.getScale(proxy: proxy)
                        VStack {
                            NavigationLink(destination: ContentDetailsView(text: movie.title),
                                   label: {
                                TopCard(title: movie.title, backdropPath: movie.backdrop_path, rating: movie.vote_average)
                                       .frame(width: 300, height: 200, alignment: .center)
                                   })
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


