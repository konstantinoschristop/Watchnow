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

/// Sheet wrapper around `WebView`. Wrapped in a `NavigationStack` so the
/// dismiss control is just a native "Done" toolbar button rather than a
/// custom-styled X overlay — iOS handles the styling, safe areas, and
/// large-screen layout for free.
struct WebViewSheet: View {

    let url: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WebView(videoURL: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close")
                    }
                }
        }
    }
}
