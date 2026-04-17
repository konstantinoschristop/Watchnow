//
//  SectionHeaderView.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI

// MARK: - Section Header View (Title Section)

/// Section header with an optional tinted icon + rail + live-pulse dot
/// and an optional trailing accessory slot (e.g., a "See all" button or a
/// segmented picker). Keeps typography and padding uniform across the app
/// while letting each section carry its own personality — a flame for
/// trending, a calendar for Coming Soon, etc.
struct SectionHeaderView<Accessory: View>: View {
    var title: String
    var subtitle: String? = nil
    /// SF Symbol rendered at the leading edge. `nil` → no icon, no rail.
    var icon: String? = nil
    /// Drives the rail colour and the icon tint. Ignored when `icon` is nil.
    var tint: Color = .accentColor
    /// Adds a small red pulse dot on the icon to signal "live / real-time".
    var showsPulse: Bool = false
    let accessory: Accessory

    init(title: String,
         subtitle: String? = nil,
         icon: String? = nil,
         tint: Color = .accentColor,
         showsPulse: Bool = false,
         @ViewBuilder accessory: () -> Accessory) {

        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.showsPulse = showsPulse
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let icon {
                // 3pt capsule rail carries the section's theme colour right
                // at the reading entry point — quick visual anchor even on
                // a busy scroll.
                Capsule()
                    .fill(tint)
                    .frame(width: 3, height: 24)

                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                        .symbolRenderingMode(.hierarchical)

                    if showsPulse {
                        PulseDot()
                            .offset(x: 3, y: -3)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
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
            accessory
        }
        .padding(.horizontal)
    }
}

// Back-compat initializer so existing callers `SectionHeaderView(title:)` /
// `SectionHeaderView(title:subtitle:)` continue to work without an accessory.
extension SectionHeaderView where Accessory == EmptyView {
    init(title: String,
         subtitle: String? = nil,
         icon: String? = nil,
         tint: Color = .accentColor,
         showsPulse: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.showsPulse = showsPulse
        self.accessory = EmptyView()
    }
}

// MARK: - PulseDot

/// Small red dot with a concentric ring that pulses outward on repeat.
/// Signals a "live" feed — same grammar as sports scoreboards and
/// trending topic widgets. Uses `TimelineView(.animation)` so the
/// animation is driven by the display link rather than SwiftUI's
/// implicit animation graph, which keeps the repeat crisp even when
/// nested inside a lazy scroll.
private struct PulseDot: View {
    private let tint: Color = .red
    private let coreSize: CGFloat = 6

    var body: some View {
        TimelineView(.animation) { context in
            // 0 → 1 → 0 sinusoidal in a 1.6s window. Keeps the pulse slow
            // enough to read as "heartbeat" rather than "alarm".
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = (sin(t * .pi / 0.8) + 1) / 2 // 0…1

            ZStack {
                // Expanding halo
                Circle()
                    .fill(tint.opacity(0.45 * (1 - phase)))
                    .frame(width: coreSize + CGFloat(phase) * 10,
                           height: coreSize + CGFloat(phase) * 10)
                Circle()
                    .fill(tint)
                    .frame(width: coreSize, height: coreSize)
                    .shadow(color: tint.opacity(0.6), radius: 2)
            }
        }
        .frame(width: coreSize, height: coreSize)
        .allowsHitTesting(false)
    }
}
