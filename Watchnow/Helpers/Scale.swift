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
    
    static func getScale(proxy: GeometryProxy, scaleType: ScaleTypes) -> CGFloat {
        let midPoint: CGFloat = 120
        
        let viewFrame = proxy.frame(in: CoordinateSpace.global)
        
        var scale: CGFloat = 1.0
        let deltaXAnimationThreshold: CGFloat = scaleType == .vertical ? 100 : 130
        
        let diffFromCenter = abs(midPoint - viewFrame.origin.x - deltaXAnimationThreshold / 2)
        if diffFromCenter < deltaXAnimationThreshold {
            scale = 1 + (deltaXAnimationThreshold - diffFromCenter) / 600
        }
        
        return scale
    }
}


