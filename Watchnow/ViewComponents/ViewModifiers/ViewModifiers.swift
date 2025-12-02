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

// MARK: - ViewDidLoadModifier
struct ViewDidLoadModifier: ViewModifier {
    
    @State private var isViewAppeared: Bool = false
    var action: () -> ()
    
    init(action: @escaping () -> ()) {
        self.action = action
    }
    
    func body(content: Content) -> some View {
        content.onAppear {
            if !self.isViewAppeared {
                self.action()
            }
            self.isViewAppeared.toggle()
        }
    }
}

// MARK: - StretchEffectModifier
struct StretchEffectModifier: ViewModifier {
    
    func body(content: Content) -> some View {
        content
            .visualEffect { effect, geometry in
                let currentHeight = geometry.size.height
                let scrollOffset = geometry.frame(in: .scrollView).minY
                let positiveOffset = max (0, scrollOffset)
                
                let newHeight = currentHeight + positiveOffset
                let scaleFactor = newHeight / currentHeight
                
                return effect.scaleEffect(x: scaleFactor,
                                          y: scaleFactor,
                                          anchor: .bottom)
            }
    }
}
