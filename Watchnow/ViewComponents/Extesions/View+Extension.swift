//
//  View+Extension.swift
//  Watchnow
//
//  Created by k.christopoulos on 20/9/25.
//

import SwiftUI

extension View {
    /// Applies tab bar minimization behavior if available.
    func minimizeTabBar() -> some View {
        self.modifier(TabBarMinimizeModifier())
    }
    
    /// Applies tab bar minimization behavior if available.
    func hideBackButtonOptionally() -> some View {
        self.modifier(NavigationBarBackButtonModifier())
    }
    
    func onLoad(perform action: @escaping () -> ()) -> some View {
        self.modifier(ViewDidLoadModifier(action: action))
    }
}
