//
//  CastView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/2/22.
//

import SwiftUI
import Kingfisher

struct CastView: View {
    
    let cast: [Cast]
    
    init(cast: [Cast]?) {
        guard let cast = cast else {
            self.cast = []
            return
        }
        
        self.cast = cast
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(cast, id: \.self) { cast in
                    NavigationLink {
                        ActorDetailsView(actorID: cast.id)
                    } label: {
                        VStack {
                            if let imageURL = cast.profile_path,
                               let url = APIKeys().imageKey + imageURL {
                                
                                GenericImageView.init(url: url,
                                                      width: 80,
                                                      height: 120,
                                                      cornerRadius: 6,
                                                      showShadow: true)
                                
                                    .aspectRatio(contentMode: .fit)
                                Text((cast.name ?? cast.original_name) ?? "")
                                    .font(.system(size: 12, weight: .heavy))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(Color(.systemBackground))
                                    .colorInvert()
                                    .frame(width: 80, height: 30)
                            }
                        }
                        .frame(width: 80, height: 170)
                    }
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
        }
    }
}
