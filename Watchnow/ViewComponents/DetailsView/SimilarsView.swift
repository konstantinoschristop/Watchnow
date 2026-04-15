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
    var namespace: Namespace.ID
    
    var body: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(content, id: \.self) { content in
                    if let imageURL = content.poster_path {
                        ZStack {
                            NavigationLink {
                                let model = ContentDetailsModel(screenType: screenType, result: content)
                                let vm = ContentDetailsViewModel(model: model)
                                ContentDetailsView(detailsViewModel: vm)
                                    .navigationTransition(.zoom(sourceID: content.id, in: namespace))
                            } label: {
                                VStack {
                                    let url = API.Common.imageUrl(imageId: imageURL)
                                        
                                        GenericImageView.init(url: url,
                                                              width: 130,
                                                              height: 180,
                                                              cornerRadius: 10,
                                                              showShadow: true)
                                        
                                            .aspectRatio(contentMode: .fit)
                                        Text(content.getResultTitle())
                                            .font(.system(size: 15, weight: .heavy))
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(Color(.systemBackground))
                                            .colorInvert()
                                            .frame(width: 130, height: 50, alignment: .top)
                                }
                                .padding(.leading, 15)
                            }
                            HStack {
                                (Text(Image(systemName: "star.fill")) + Text(" ") + Text(String(format: "%.1f", content.vote_average ?? "-"))
                                    .foregroundColor(.gray))
                                .font(.system(size: 12, weight: .regular))
                                .padding(.vertical, 5)
                                .padding(.horizontal, 9)
                                .background(Color(.secondaryBackground))
                                .foregroundColor(.orange)
                                .cornerRadius(10)
                                .offset(x: 50 , y: -120)
                            }
                        }
                        .frame(width: 130, height: 270)
                    }
                }
            }
            .padding(.trailing, 15)
        }
    }
}
