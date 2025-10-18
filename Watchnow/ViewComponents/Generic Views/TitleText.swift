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
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(Color(.systemBackground))
            .colorInvert()
    }
}
