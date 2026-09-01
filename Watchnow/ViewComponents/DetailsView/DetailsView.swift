//
//  DetailsView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 28/8/22.
//

import SwiftUI

/// Overview section for the details screen. Displays the synopsis with a
/// "Read more" toggle when it overflows the collapsed line limit.
/// Rating/year/runtime have been moved into the hero overlay.
struct DetailsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    var details: ResultDetailsResponse?

    private let collapsedLineLimit = 4
    // Character threshold roughly equivalent to 4 lines of body text at
    // typical widths; used to decide whether a "Read more" is worth showing.
    private let expandThreshold = 220

    @State private var isExpanded = false

    var body: some View {
        if let overview = details?.overview, !overview.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(overview)
                    .appFont(15, relativeTo: .subheadline)
                    .lineLimit(isExpanded ? nil : collapsedLineLimit)
                    .animation(reduceMotion ? nil : .easeInOut(duration: AppMotion.quick), value: isExpanded)

                if overview.count > expandThreshold {
                    Button {
                        withAnimation { isExpanded.toggle() }
                    } label: {
                        // Accent, not `.blue` — every other interactive
                        // affordance on this screen (section See-all, rails,
                        // CTAs) uses `.accentColor`, so matching keeps the
                        // theming coherent top-to-bottom.
                        Text(isExpanded ? "Read less" : "Read more")
                            .appFont(14, weight: .semibold, relativeTo: .subheadline)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 15)
        }
    }
}
