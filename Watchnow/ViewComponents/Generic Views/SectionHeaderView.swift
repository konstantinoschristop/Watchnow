//
//  SectionHeaderView.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI

// MARK: - Section Header View (Title Section)
struct SectionHeaderView: View {
    var title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 25, weight: .heavy))
            Spacer()
        }
        .padding(.horizontal)
    }
}
