//
//  TitleText.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI

// MARK: - TitleText Component
struct TitleText: View {
    var title: String
    
    var body: some View {
        Text(title)
            .appFont(12, weight: .heavy, relativeTo: .caption)
            .foregroundColor(Color(.systemBackground))
            .colorInvert()
    }
}
