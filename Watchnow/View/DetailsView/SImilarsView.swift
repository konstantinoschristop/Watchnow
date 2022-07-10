//
//  SimilarsView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 5/6/22.
//

import SwiftUI
import Kingfisher

struct SimilarsView: View {
    
    let content: [Result]
    let screenType: ScreenTypes
    
    var body: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(content, id: \.self) { content in
                    ZStack {
                        NavigationLink {
                            ContentDetailsView(result: content, screenType: screenType)
                        } label: {
                            VStack {
                                if let imageURL = content.poster_path,
                                   let url = APIKeys().imageKey + imageURL {
                                    
                                    GenericImageView.init(url: url, width: 130, height: 180)
                                        .aspectRatio(contentMode: .fit)
                                        .cornerRadius(15)
                                        .shadow(color: .gray, radius: 3)
                                    Text(content.getResultTitle())
                                        .font(.system(size: 15, weight: .heavy))
                                        .foregroundColor(Color(.systemBackground))
                                        .colorInvert()
                                        .frame(width: 130, height: 50, alignment: .top)
                                }
                            }
                            .padding(.leading, 10)
                        }
                        HStack {
                            (Text(Image(systemName: "star.fill")) + Text(" ") + Text(String(format: "%.1f", content.vote_average ?? "-"))
                                .foregroundColor(.gray))
                            .font(.system(size: 12, weight: .regular))
                            .padding(.vertical, 5)
                            .padding(.horizontal, 9)
                            .background(Color(.systemGray5))
                            .foregroundColor(.orange)
                            .cornerRadius(10)
                            .offset(x: 50 , y: -120)
                        }
                    }
                    .frame(width: 130, height: 270)
                }
            }
        }
    }
}
