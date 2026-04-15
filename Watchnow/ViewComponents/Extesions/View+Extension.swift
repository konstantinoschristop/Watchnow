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
}
