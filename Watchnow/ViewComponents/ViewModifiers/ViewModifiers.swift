//
//  ViewModifiers.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI

// MARK: - TabBarMinimizeModifier
struct TabBarMinimizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

// MARK: - NavigationBarBackButtonModifier
struct NavigationBarBackButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.navigationBarBackButtonHidden(false)
        } else {
            content.navigationBarBackButtonHidden(true)
        }
    }
}

struct SoftScrollEdgeEffectStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

// MARK: - ViewDidLoadModifier
struct ViewDidLoadModifier: ViewModifier {
    
    @State private var isViewAppeared: Bool = false
    var action: () -> ()
    
    init(action: @escaping () -> ()) {
        self.action = action
    }
    
    func body(content: Content) -> some View {
        content.onAppear {
            guard !self.isViewAppeared else { return }
            self.isViewAppeared = true
            self.action()
        }
    }
}

// MARK: - StretchEffectModifier
struct StretchEffectModifier: ViewModifier {
    
    func body(content: Content) -> some View {
        content
            .visualEffect { effect, geometry in
                // Guarded against a zero height (which would divide to NaN
                // and drop the view entirely) and against an implausible
                // offset. `frame(in: .scrollView).minY` can report a large
                // value for a frame or two while a scroll view's geometry
                // is still resolving — on a tab switch, for instance —
                // which without a cap scales the content far past the
                // screen and leaves the header looking broken until it
                // settles. One band-height of stretch is already more than
                // any real overscroll produces.
                let currentHeight = max(geometry.size.height, 1)
                let scrollOffset = geometry.frame(in: .scrollView).minY
                let positiveOffset = min(max(0, scrollOffset), currentHeight)

                let newHeight = currentHeight + positiveOffset
                let scaleFactor = newHeight / currentHeight
                
                return effect.scaleEffect(x: scaleFactor,
                                          y: scaleFactor,
                                          anchor: .bottom)
            }
    }
}
