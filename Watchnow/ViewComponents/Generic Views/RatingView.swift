//
//  RatingView.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI

// MARK: - RatingView Component
struct RatingView: View {
 
    var rating: Double?
    
    var body: some View {
        
        (Text(Image(systemName: "star.fill")) + Text(" ") + Text(String(format: "%.1f", rating ?? "-"))
            .foregroundColor(.white))
        .font(.system(size: 11, weight: .bold))
        .padding(.vertical, 5)
        .padding(.horizontal, 9)
        .foregroundColor(.orange)
    }
}
