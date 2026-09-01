//
//  DesignTokens.swift
//  Watchnow
//
//  The shape and timing vocabulary the whole app draws from.
//
//  Before this existed the app had fourteen distinct corner radii (0, 4, 5,
//  6, 7, 8, 9, 10, 12, 14, 16, 18, 20, 22) and seventeen animation
//  durations. None of it was wrong in isolation — each value had been chosen
//  against the thing next to it — but collectively it meant two cards on the
//  same screen could round differently for no reason a reader could name,
//  and a tap could resolve in 0.15s on one screen and 0.3s on another.
//
//  The values here are deliberately the app's *own* vocabulary rounded onto
//  a 4pt scale, not an imported system: nothing moves by more than 2pt, so
//  adopting them is invisible on every screen while making the next screen
//  consistent by default.
//
//  Colour is not in here on purpose. Surfaces already resolve through the
//  semantic asset tokens (`Color(.background)`, `.secondarySystemBackground`,
//  `.tertiarySystemFill`), which is exactly where they belong — they adapt
//  to light and dark without this file's help.
//

import SwiftUI

// MARK: - Radius

/// Corner radii, named by the role of the surface rather than by size, so a
/// call site says what it is drawing instead of picking a number.
enum AppRadius {

    /// Skeleton bars, inline marks, tiny inset artwork. Small enough that the
    /// radius reads as "not sharp" rather than as a shape.
    static let micro: CGFloat = 4

    /// Compact thumbnails and tiles up to roughly 48pt — provider logos,
    /// fanned folder covers, marquee posters, inline name fields.
    static let small: CGFloat = 8

    /// The workhorse: posters in rows and grids, cast portraits, ad
    /// thumbnails, standard content cards.
    static let card: CGFloat = 12

    /// Buttons and mid-weight panels — anything that reads as a control or a
    /// grouped block rather than as a piece of artwork.
    static let panel: CGFloat = 16

    /// Hero surfaces: the briefing cards, swipe-deck cards, featured
    /// carousel slides, sheets. The roundest thing on any screen.
    static let hero: CGFloat = 20

    /// A `RoundedRectangle` at the given role, always `.continuous` — the
    /// squircle Apple uses, and the one the rest of the app already picked.
    static func shape(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

// MARK: - Motion

/// Animation timings, named by intent.
///
/// Four tiers, chosen so the two the app already leaned on (0.2 and 0.25,
/// between them more than half of every duration in the codebase) survive
/// unchanged as `quick` and `standard`.
///
/// Reduce Motion is deliberately *not* baked in here. Every call site that
/// animates should hold `@Environment(\.accessibilityReduceMotion)` and pass
/// `nil` when it is on — reading the setting from the environment is what
/// makes SwiftUI re-evaluate the view when the user changes it mid-session,
/// which a static lookup inside this enum could not do.
enum AppMotion {

    /// State flips the user is watching happen under their finger: chip
    /// selection, press feedback, a filter changing.
    static let quick: Double = 0.2

    /// The default for content changing: cross-fades, list reflows, a screen
    /// swapping one layout for another.
    static let standard: Double = 0.25

    /// Something arriving that deserves to be noticed — a sheet's contents,
    /// a staggered entrance.
    static let emphasis: Double = 0.35

    /// Deliberate, once-per-screen motion. Anything slower than this is
    /// ambient (a drift, a sheen) and belongs to the view that owns it, not
    /// to this scale.
    static let slow: Double = 0.5

    /// Leaving is faster than arriving — roughly two thirds. An exit that
    /// matches its entrance reads as sluggish, because the user has already
    /// decided and is waiting on the UI to agree.
    static var exit: Double { standard * 0.65 }

    // MARK: Curves

    /// Content settling into place.
    static let ease = Animation.easeOut(duration: standard)

    /// Content leaving.
    static let easeOut = Animation.easeIn(duration: exit)

    /// Two-way transitions where neither end is an arrival.
    static let crossfade = Animation.easeInOut(duration: standard)

    /// Springs, for anything the user physically moved. Response values
    /// match what the app had already converged on by hand.
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let springSoft = Animation.spring(response: 0.42, dampingFraction: 0.85)
    static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.62)
}

// MARK: - Touch

enum AppTouch {
    /// Apple's minimum comfortable target. Use it as a `minWidth`/`minHeight`
    /// floor around small glyphs rather than by inflating the glyph itself —
    /// the visible mark and the tappable area are allowed to differ, and
    /// usually should.
    static let minTarget: CGFloat = 44
}

// MARK: - Type

/// Text sizing.
///
/// The app was built on 219 fixed `.system(size:)` values, which meant it
/// ignored the reader's text-size setting completely — on every screen, at
/// every size.
///
/// `.appFont(_:weight:relativeTo:)` keeps each carefully-chosen size as the
/// *base* and scales from there, so the design is preserved exactly at the
/// default setting and still grows for anyone who needs it to. That is the
/// whole trade: nothing looks different today, and the app stops being
/// unusable at 200%.
///
/// Note there is no `Font.system(size:weight:relativeTo:)` in SwiftUI — a
/// fixed point size simply does not scale. `@ScaledMetric` is the primitive
/// that does, and it has to live in a view, which is why this is a modifier
/// rather than a `Font` extension. It reads the environment, so a local
/// `.dynamicTypeSize(...)` clamp applies to it correctly.
private struct ScaledFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {

    /// A system font at `size` that scales with the reader's text setting.
    ///
    /// Drop-in for `.font(.system(size:weight:design:))`. Pick `relativeTo`
    /// by the *role* of the text, not by which style happens to share its
    /// size — body copy should grow like body copy even when it is set at
    /// 15pt, and a 25pt section heading should grow like a title.
    func appFont(_ size: CGFloat,
                 weight: Font.Weight = .regular,
                 relativeTo style: Font.TextStyle = .body,
                 design: Font.Design = .default) -> some View {
        modifier(ScaledFontModifier(size: size,
                                    weight: weight,
                                    design: design,
                                    relativeTo: style))
    }
}

// MARK: - Dynamic Type clamps

extension View {

    /// Caps how far text in this subtree will grow.
    ///
    /// Used on the poster grids, carousels and cards — layouts whose whole
    /// job is to show a fixed number of covers across, and which stop being
    /// able to do that somewhere past the accessibility sizes. Everything
    /// text-led (details, reviews, the person sheet, episodes, Movie Coach)
    /// is deliberately left uncapped, because that is where reading actually
    /// happens and where someone who needs 200% text most needs it honoured.
    ///
    /// A clamp is a compromise, not a fix, and it is only defensible when the
    /// same information is reachable somewhere uncapped — which it is: every
    /// cover in a grid opens a details screen that scales without limit.
    func artworkTypeClamp() -> some View {
        dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// Tighter clamp for the few places where text shares a fixed-height row
    /// with artwork and has nowhere to grow into at all.
    func compactTypeClamp() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}
