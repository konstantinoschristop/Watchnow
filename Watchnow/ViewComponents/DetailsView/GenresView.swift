//
//  GenresView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 28/8/22.
//

import SwiftUI

struct GenresView: View {
    
    let genres: [Genres]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(genres, id: \.self) { genre in
                    Text(genre.name ?? "- -")
                        .padding()
                        .appFont(11, relativeTo: .caption2)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                }
            }
            .padding(.all, 15)
        }
    }
}

