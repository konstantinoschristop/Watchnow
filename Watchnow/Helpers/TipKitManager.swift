//
//  TipKitManager.swift
//  Watchnow
//
//  Created by k.christopoulos on 28/10/23.
//

import Foundation
import TipKit

//struct TipKitManager: Tip {
//    
//    var id: String
//    var title: Text
//    var message: Text?
//    var image: Image?
//    
//    init(title: String,
//         message: String?,
//         imageName: String?) {
//        
//        self.id = UUID().uuidString
//        self.title = constructTitle(with: title)
//        if let message {
//            self.message = constructMessage(with: message)
//        }
//        if let imageName {
//            self.image = constructImage(with: imageName)
//        }
//    }
//    
//    private func constructTitle(with text: String) -> Text {
//        
//    }
//    
//    private func constructMessage(with text: String) -> Text {
//        
//    }
//    
//    private func constructImage(with imageName: String) -> Image {
//        
//    }
//}

@available(iOS 17.0, *)
struct MyTip: Tip {
    
    var id: String {
        UUID().uuidString
    }
    
    var title: Text {
        Text("This is a tip title")
    }
    
    var message: Text? {
        Text("This is a tip message")
    }
    
    var image: Image? {
        Image(systemName: "arrow.down")
    }
    
    var rules: [Rule] {
        #Rule($hasViewedTip) { $0 == true }
    }
    
    @Parameter
    private var hasViewedTip: Bool = false
    
    mutating func dismissTip() {
        self.invalidate(reason: .actionPerformed)
        hasViewedTip = true
    }
}
