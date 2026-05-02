//
//  Scale.swift
//  Watchnow
//
//  Created by k.christopoulos on 27/11/21.
//

import SwiftUI

class Scale {
    enum ScaleTypes {
        case vertical
        case horizontal
    }

    /// Marked `@MainActor` because `UIScreen.main.bounds` is main-actor
    /// isolated under Swift 6 / strict concurrency. All callers live in
    /// SwiftUI view bodies (also main-actor by default), so this is a
    /// no-op at the call site.
    @MainActor
    static func getScale(proxy: GeometryProxy, scaleType: ScaleTypes) -> CGFloat {
        let screenCenter = UIScreen.main.bounds.width / 2
        let cardCenter   = proxy.frame(in: .global).midX
        let diff         = abs(screenCenter - cardCenter)
        let threshold: CGFloat = scaleType == .vertical ? 150 : 160

        guard diff < threshold else { return 1.0 }
        return 1 + (threshold - diff) / 600
    }
}
