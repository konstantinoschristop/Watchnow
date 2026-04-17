//
//  LoadMoreButtonView.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI

// MARK: - Load More Button View (For Fetching More Content)
struct LoadMoreButtonView: View {

    /// 0.0 = no overscroll, 1.0 = threshold reached
    var progress: CGFloat

    private var size: CGFloat    { 34 + (progress * 18) }  // 34pt → 52pt
    private var opacity: CGFloat { 0.5 + (progress * 0.5) } // 50% → 100%

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.2), radius: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: max(11, size * 0.3), weight: .semibold))
                .foregroundStyle(.primary)
        }
        .opacity(opacity)
        .frame(maxHeight: .infinity)
        .padding(.leading, 24)
        .padding(.trailing, 16)
    }
}
