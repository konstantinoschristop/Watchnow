//
//  RatingView.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI

// MARK: - RatingView Component
struct RatingView: View {
    
    enum CardType {
        case top
        case bottom
    }
    
    var rating: Double?
    let cardType: CardType
    
    var body: some View {
        HStack {
            (Text(Image(systemName: "star.fill")) + Text(" ") + Text(String(format: "%.1f", rating ?? "-"))
                .foregroundColor(.gray))
                .font(.system(size: 14, weight: .regular))
                .padding(.vertical, 5)
                .padding(.horizontal, 9)
                .background(Color(.systemGray5))
                .foregroundColor(.orange)
                .cornerRadius(10)
        }
        .offset(x: getXOffset(), y: getYOffset())
    }
    
    private func getXOffset() -> CGFloat {
        if cardType == .top {
            return 120
        } else {
            return 60
        }
    }
    
    private func getYOffset() -> CGFloat {
        if cardType == .top {
            return -100
        } else {
            return -150
        }
    }
}
