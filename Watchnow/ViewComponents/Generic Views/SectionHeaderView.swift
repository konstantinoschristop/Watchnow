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
    var subtitle: String? = nil
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.system(size: 25, weight: .heavy))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }
}
