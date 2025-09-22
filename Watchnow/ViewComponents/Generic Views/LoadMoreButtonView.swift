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
        let imageName: String = thresholdReached ? "checkmark.circle.dotted" : "chevron.left.chevron.left.dotted"
        
        Image(systemName: imageName)
            .resizable()
            .foregroundStyle(thresholdReached ? Color.green : Color.primary)
            .frame(width: 30, height: 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)
    }
}
