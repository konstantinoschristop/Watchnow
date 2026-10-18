//
//  View+Extension.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI
import UIKit

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Applies tab bar minimization behavior if available.
    func minimizeTabBar() -> some View {
        self.modifier(TabBarMinimizeModifier())
    }
    
    /// Applies tab bar minimization behavior if available.
    func hideBackButtonOptionally() -> some View {
        self.modifier(NavigationBarBackButtonModifier())
    }
    
    /// ViewDidLoad
    func onLoad(perform action: @escaping () -> ()) -> some View {
        self.modifier(ViewDidLoadModifier(action: action))
    }
    
    /// Applies stretchy header effect
    func stretchy() -> some View {
        self.modifier(StretchEffectModifier())
    }

    /// `.ignoresSafeArea(edges:)` only when `enabled`.
    ///
    /// Named distinctly rather than overloading `ignoresSafeArea` so a call
    /// site can never accidentally resolve to the wrong one.
    @ViewBuilder
    func bleedingSafeArea(_ enabled: Bool, edges: Edge.Set) -> some View {
        if enabled {
            self.ignoresSafeArea(edges: edges)
        } else {
            self
        }
    }

    /// `.clipped()` only when `enabled`.
    ///
    /// For views that need to clip in one state and deliberately overflow in
    /// another — a header that collapses to zero height (clip) but also
    /// stretches past its own frame on overscroll (don't clip).
    @ViewBuilder
    func clipped(_ enabled: Bool) -> some View {
        if enabled {
            self.clipped()
        } else {
            self
        }
    }
}

extension View {

    /// Strips a `List` row back to plain content: no separator, no inset, no
    /// cell background. The home feed uses `List` for its cell recycling, not
    /// for its table styling — see `ContentMainView`.
    func feedRow() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

// MARK: - Debug-only text

#if DEBUG
// The debug screens' text is never translated, so it is kept out of the
// String Catalog. Plain literals would be extracted into it — and since a
// Release build doesn't compile these screens, every archive would drop the
// entries and the next Debug build would add them back.

extension Button where Label == Text {
    /// A button whose title is shown as written, never localized.
    init(debug title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(role: role, action: action) { Text(verbatim: title) }
    }
}

extension Section where Parent == Text, Content: View, Footer == EmptyView {
    /// A section whose header is shown as written, never localized.
    init(debug title: String, @ViewBuilder content: () -> Content) {
        self.init(content: content, header: { Text(verbatim: title) })
    }
}
#endif
