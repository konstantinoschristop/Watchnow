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

/// Sheet wrapper around `WebView` that adds an explicit close affordance.
/// The system swipe-down still works, but a visible "X" pinned to the top
/// trailing corner makes dismissal obvious — especially useful for the
/// JustWatch / provider deeplinks where the page chrome can obscure the
/// sheet's grabber.
struct WebViewSheet: View {

    let url: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WebView(videoURL: url)
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.55))
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }
                .padding(.top, 56)
                .padding(.trailing, 16)
                .accessibilityLabel("Close")
            }
    }
}
