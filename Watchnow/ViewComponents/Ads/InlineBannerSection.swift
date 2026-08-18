//
//  InlineBannerSection.swift
//  Watchnow
//
//  Self-contained banner row for the main content lists.
//
//  Three states, deliberately distinct:
//
//   - loading  Reserve a 50pt slot. The reservation isn't cosmetic: a
//              zero-size section can be skipped entirely by the enclosing
//              LazyVStack, so the banner would never mount and never
//              request. Nothing is drawn in it — no "Ad" label — so a slot
//              that never fills reads as blank space, not a broken ad.
//   - loaded   Collapse to the creative's exact height, with hairlines.
//   - failed   Render nothing at all: no dividers, no reserved height.
//
//  Previously the failed case kept the 50pt box (and an "Ad" label) forever,
//  which left a dead grey band on the Movies, Series, Details, Search and
//  Watchlist screens whenever a request didn't fill.
//

import SwiftUI
import UIKit

struct InlineBannerSection: View {

    private let placeholderHeight: CGFloat = 50

    @State private var state: BannerAdState = .loading
    @State private var containerWidth: CGFloat = 0

    /// Width of the key window — used as a fallback when GeometryReader
    /// reports 0 (e.g. when this view is laid out before the surrounding
    /// LazyVStack has propagated a width down to it).
    private var fallbackWidth: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .bounds.width ?? 320
    }

    private var resolvedWidth: CGFloat {
        containerWidth > 0 ? containerWidth : fallbackWidth
    }

    var body: some View {
        if state == .failed {
            // No fill — take up no space whatsoever.
            EmptyView()
        } else {
            VStack(spacing: 0) {
                Divider().opacity(state.height > 0 ? 0.25 : 0)

                BannerAdView(state: $state, width: resolvedWidth)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(state.height, placeholderHeight))
                    .clipped()

                Divider().opacity(state.height > 0 ? 0.25 : 0)
            }
            .frame(maxWidth: .infinity)
            // Read the container width without affecting layout.
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: BannerWidthKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(BannerWidthKey.self) { containerWidth = $0 }
        }
    }
}

// MARK: - Preference key

private struct BannerWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
