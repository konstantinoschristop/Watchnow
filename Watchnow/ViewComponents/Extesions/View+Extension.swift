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
