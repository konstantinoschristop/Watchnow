//
//  DetailsView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 28/8/22.
//

import SwiftUI

struct DetailsView: View {
    
    var result: Result
    
    var body: some View {
        VStack(alignment: .center) {
            ZStack {
                VStack {
                    if let overview = result.overview {
                        Text(overview)
                    }
                    Spacer()
                        .frame(height: 20)
                    HStack {
                        if let rating = result.vote_average {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f", rating) + "/10")
                        }
                        if let allRatings = result.vote_count {
                            Text("• " + String(allRatings) + " ratings")
                        }
                        Text("• " + result.getReleaseDate(addSeparator: false))
                    }
                    .font(.custom("AvenirNext-Regular", size: 15))
                    .foregroundColor(.gray)
                }
            }
        }
        .padding(.init(top: 0, leading: 15, bottom: 0, trailing: 15))
    }
}
