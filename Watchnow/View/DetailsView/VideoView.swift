//
//  VideoView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 30/7/22.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    
    let videoURL: URL?
    
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        
        DispatchQueue.main.async {
            if let videoURL = videoURL {
                uiView.load(.init(url: videoURL))
            }
        }
    }
}

