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
            content.tabBarMinimizeBehavior(.automatic)
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

// MARK: - NavigationBarBackButtonModifier
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
