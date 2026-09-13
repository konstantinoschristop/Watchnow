//
//  TabSwitchMotion.swift
//  Watchnow
//
//  Gives switching tabs a sense of travel.
//
//  A native `TabView` offers no hook for transitioning between tabs — the
//  system crossfades the content and that is the whole of it. Replacing it
//  with a custom pager would buy a real transition and cost the iOS 26 tab
//  bar, the search tab's system behaviour, and the accessibility that comes
//  free with both. Not worth it.
//
//  So the motion lives one level in: each tab's *content* arrives when its
//  tab becomes selected, sliding from the side it was reached from. Going
//  right feels like going right. The tab bar stays entirely the system's.
//

import SwiftUI

struct TabSwitchMotion: ViewModifier {

    let isActive: Bool
    /// Positive when this tab sits to the right of the one being left, so
    /// content enters from the correct side.
    let direction: Int
    let reduceMotion: Bool

    private var offset: CGFloat {
        guard !isActive, !reduceMotion else { return 0 }
        return CGFloat(direction) * 24
    }

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .scaleEffect(isActive || reduceMotion ? 1 : 0.97, anchor: .center)
            .offset(x: offset)
            .animation(reduceMotion
                       ? .easeOut(duration: AppMotion.standard)
                       : .spring(response: 0.42, dampingFraction: 0.85),
                       value: isActive)
    }
}

extension View {
    /// Applies the arrival motion for a tab's content.
    func tabSwitchMotion(isActive: Bool, direction: Int, reduceMotion: Bool) -> some View {
        modifier(TabSwitchMotion(isActive: isActive, direction: direction, reduceMotion: reduceMotion))
    }
}
