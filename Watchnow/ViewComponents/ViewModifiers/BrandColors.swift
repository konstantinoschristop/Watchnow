//
//  BrandColors.swift
//  Watchnow
//
//  The WatchNow icon's own palette, as handed over with the v2.1 artwork.
//
//  These are the colours the icon is drawn in and the backgrounds it is
//  meant to sit on — not the app's UI palette. The app's surfaces still
//  resolve through the semantic asset tokens (`Color(.background)`,
//  `.secondarySystemBackground`) so they keep adapting to light and dark on
//  their own, and the tint still comes from `AccentColor`.
//
//  Note the app's accent (#2D5BD9) and the icon's blue (#1455E6) are not the
//  same blue. That is deliberate for now: repainting every tinted control in
//  the app is a visible change nobody asked for. If the two should be
//  reconciled, change `AccentColor.colorset` — not this file.
//

import SwiftUI

extension Color {

    /// `#RRGGBB` or `#AARRGGBB`. Kept `fileprivate`-adjacent in spirit: it
    /// exists so the brand values below can be written the way they were
    /// specified, not as a general-purpose colour parser.
    init(brandHex hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        self.init(.sRGB,
                  red:   Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue:  Double(value & 0xFF) / 255,
                  opacity: 1)
    }
}

enum WatchnowBrand {

    // MARK: - Icon palette

    static let blue = Color(brandHex: "#1455E6")
    static let gold = Color(brandHex: "#F5B940")
    /// The off-white of the card the film strip sits on.
    static let card = Color(brandHex: "#F5F6FA")

    // MARK: - Backgrounds behind the icon

    /// Slightly darker than pure white, so the off-white card still reads as
    /// a card rather than disappearing into the page. Notably *not* the same
    /// value as `card` — that was the flaw in the supplied light background,
    /// which matched the card almost exactly.
    static let backgroundLight = Color(brandHex: "#F2F3F6")

    /// Vertical, dark at the top to blue at the bottom — the direction the
    /// supplied artwork uses.
    static let backgroundDarkTop = Color(brandHex: "#06101F")
    static let backgroundDarkBottom = Color(brandHex: "#0F2A6B")

    /// The launch screen's gradient, should anything need to reproduce it in
    /// SwiftUI. The launch screen itself is a storyboard and cannot run
    /// code, so it uses the `LaunchBackground` image asset instead.
    static var launchGradient: LinearGradient {
        LinearGradient(colors: [backgroundDarkTop, backgroundDarkBottom],
                       startPoint: .top, endPoint: .bottom)
    }
}
