//
//  BottomView.swift
//  Watchnow
//
//  Created by k.christopoulos on 27/11/21.
//

import SwiftUI

struct BottomView: View {
    
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
            HStack(alignment: .top, spacing: 5) {
                Spacer()
                    .frame(width: 10)
                ForEach(results, id: \.self) { movie in

                    GeometryReader { proxy in
                        let scale = Scale.getScale(proxy: proxy)
                        VStack {
                            NavigationLink(destination: ContentDetailsView(text: movie.title),
                                   label: {
                                BottomCard(title: movie.title, posterPath: movie.poster_path, rating: movie.vote_average)
                                      .frame(width: 200, height: 300, alignment: .center)
                                   })
                        }
                        .scaleEffect(.init(width: scale, height: scale))
                        .animation(.easeOut, value: 1)
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
