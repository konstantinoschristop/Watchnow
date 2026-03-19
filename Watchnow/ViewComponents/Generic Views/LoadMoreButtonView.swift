//
//  LoadMoreButtonView.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI

// MARK: - Load More Button View (For Fetching More Content)
struct LoadMoreButtonView: View {
    
    var thresholdReached : Bool
    
    var body: some View {
        let frame: CGFloat = thresholdReached ? 50 : 40
        
            Image(systemName: "chevron.left.chevron.left.dotted")
                .resizable()
                .symbolEffect(.scale)
                .padding(14)
                .background(Color(.gray))
                .clipShape(.circle)
                .frame(width: frame, height: frame)
                .scaledToFill()
//                .frame(width: 60, height: 50, alignment: .center)
              //  .padding(.horizontal)
//                .frame(maxHeight: .infinity, alignment: .center)
    }
}
