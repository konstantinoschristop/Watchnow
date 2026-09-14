//
//  BrandColors.swift
//  Watchnow
//
//  The WatchNow icon's own palette, sampled from the v2.2 artwork.
//
//  These are the colours the icon is drawn in and the backgrounds it is
//  meant to sit on — not the app's UI palette. The app's surfaces still
//  resolve through the semantic asset tokens (`Color(.background)`,
//  `.secondarySystemBackground`) so they keep adapting to light and dark on
//  their own, and the tint still comes from `AccentColor`.
//
//  Every value below was read straight out of the artwork rather than
//  eyeballed, which is why they are odd numbers.
//
//  The mark is two overlapping cards — a blue film strip behind, a white
//  checklist card in front — on a near-white field. So the icon's *own*
//  background is light, which is why the launch screen has gone back to a
//  light/dark pair: matching the icon means matching it in light mode, and
//  the app's `Background` token is `systemGray6`/dark, so following the
//  system is also what makes the launch screen resemble the first real
//  screen.
//
//  Note the app's accent (#2D5BD9) and the icon's blues are still not the
//  same blue. That is deliberate: repainting every tinted control in the app
//  is a visible change nobody asked for. If the two should be reconciled,
//  change `AccentColor.colorset` — not this file.
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

    /// The film strip behind the card, which is the most saturated blue in
    /// the mark and the one to reach for when something needs to read as
    /// "the icon's blue". Itself a gradient — these are its two ends.
    static let blue = Color(brandHex: "#0056F6")
    static let blueLight = Color(brandHex: "#0D8AFE")
    static let blueDeep = Color(brandHex: "#0033AB")
    /// The off-white of the checklist card in front.
    static let card = Color(brandHex: "#F2F6FD")

    /// Not in the icon any more — the v2.2 artwork dropped the gold ribbon
    /// the previous mark had.
    ///
    /// Kept because onboarding still spends it deliberately: the progress
    /// rail, the confirmation tick on the services step and the picked-count
    /// are gold on purpose, as the one warm note in a flow that is otherwise
    /// entirely blue over blue. Retire this together with those, not before
    /// — dropping it on its own would leave that screen monochrome.
    static let gold = Color(brandHex: "#FEBA25")

    // MARK: - Launch screen

    /// The launch background, sampled down the vertical centre of the icon.
    ///
    /// Not the icon's corner-to-corner diagonal: a full-screen background is
    /// three times taller than it is wide, so the diagonal's horizontal
    /// component is invisible on a phone, and reading the centre line
    /// instead gives the same top-to-bottom travel the icon has.
    static let launchTop = Color(brandHex: "#F9FBFC")
    static let launchBottom = Color(brandHex: "#E5F0FD")

    /// The dark counterpart. The icon has no dark variant to sample, so this
    /// is the light ramp's shape carried into the blue-black the app's dark
    /// surfaces already live in — a launch screen that stays near-white at
    /// night would be the brightest thing on the device.
    static let launchTopDark = Color(brandHex: "#0A101C")
    static let launchBottomDark = Color(brandHex: "#06183E")

    /// The launch screen's gradients, should anything need to reproduce them
    /// in SwiftUI. The launch screen itself is a storyboard and cannot run
    /// code, so it uses the `LaunchBackground` image asset — generated from
    /// these four values — over `LaunchFallback`.
    static var launchGradient: LinearGradient {
        LinearGradient(colors: [launchTop, launchBottom],
                       startPoint: .top, endPoint: .bottom)
    }

    static var launchGradientDark: LinearGradient {
        LinearGradient(colors: [launchTopDark, launchBottomDark],
                       startPoint: .top, endPoint: .bottom)
    }
}
