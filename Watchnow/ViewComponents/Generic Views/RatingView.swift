//
//  RatingView.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI

extension Double {
    /// A 0–10 rating to one decimal place, with the app language's decimal
    /// separator: "8.4" in English, "8,4" in German or Greek.
    var ratingText: String {
        formatted(.number.precision(.fractionLength(1)))
    }
}

// MARK: - RatingView Component
struct RatingView: View {

    var rating: Double?

    var body: some View {
        (Text(Image(systemName: "star.fill")) + Text(" ") + Text(rating.map(\.ratingText) ?? "-"))
            .appFont(11, weight: .bold, relativeTo: .caption2)
            .foregroundColor(.orange)
            .padding(.vertical, 5)
            .padding(.horizontal, 9)
            .background(.black.opacity(0.55), in: Capsule())
    }
}
