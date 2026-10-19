//
//  HeroTrailerView.swift
//  Watchnow
//
//  The trailer in the details hero, played when the reader taps Trailer: a
//  player they can use, with YouTube's own controls for pause, seek, sound,
//  captions and full screen. It starts muted. The hero decides what
//  happens around it (`DetailsHeroView`'s trailer phases).
//
//  It's YouTube's IFrame player in a web view, since that's where TMDB's
//  trailers live. The player reports when it is actually playing, so the
//  hero never shows a black box or a spinner.
//
//  The app, not the page, says "play" once the player is ready: a call from
//  the page's own script counts as autoplay — the tap that asked for it is
//  long over by then — which iOS refuses outright with Auto-Play Video
//  Previews off or in Low Power Mode, while `evaluateJavaScript` runs as if
//  the user had tapped, and WebKit carries that through to YouTube's frame.
//  So it plays on every phone.
//
//  Links in the player — the title, the YouTube logo, Share — leave the
//  app rather than loading YouTube's site into the hero.
//

import SwiftUI
import WebKit

struct HeroTrailerView: UIViewRepresentable {

    let videoKey: String
    /// Touches reach the player — once it's the reader's.
    var interactive: Bool = false
    /// Lets the hero pause it.
    var remote: TrailerRemote? = nil
    /// The player has loaded and been asked to play.
    var onReady: () -> Void = {}
    /// The video is actually playing.
    let onPlaying: () -> Void
    /// It reached the end.
    let onEnded: () -> Void
    /// YouTube won't play it here (embedding disabled, removed, region).
    let onFailed: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReady: onReady, onPlaying: onPlaying, onEnded: onEnded, onFailed: onFailed)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // YouTube's full-screen button needs the page's Fullscreen API;
        // without it the button only pauses the video.
        configuration.preferences.isElementFullscreenEnabled = true
        #if DEBUG
        // `-debugTrailerRequireGesture YES` — refuse autoplay the way a phone
        // with Auto-Play Video Previews off does, on a simulator that wouldn't.
        if UserDefaults.standard.bool(forKey: "debugTrailerRequireGesture") {
            configuration.mediaTypesRequiringUserActionForPlayback = .all
        }
        #endif
        configuration.userContentController.add(context.coordinator, name: "trailer")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        // YouTube refuses to play (error 152) in an embed that doesn't say
        // which app it's in. Its rule for web views is an https referrer
        // made of the app's bundle id — which is what the page's base URL
        // becomes.
        webView.loadHTMLString(Self.html(for: videoKey, origin: Self.embedOrigin),
                               baseURL: URL(string: Self.embedOrigin))
        context.coordinator.webView = webView
        context.coordinator.remote = remote
        remote?.webView = webView
        remote?.isPlaying = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.isUserInteractionEnabled = interactive
        // Reachable by VoiceOver only once it's the reader's.
        uiView.accessibilityElementsHidden = !interactive
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "trailer")
        // Unloading is what actually stops the video.
        uiView.loadHTMLString("", baseURL: nil)
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        let onReady: () -> Void
        let onPlaying: () -> Void
        let onEnded: () -> Void
        let onFailed: () -> Void
        weak var webView: WKWebView?
        weak var remote: TrailerRemote?
        private var reportedPlaying = false

        init(onReady: @escaping () -> Void,
             onPlaying: @escaping () -> Void,
             onEnded: @escaping () -> Void,
             onFailed: @escaping () -> Void) {
            self.onReady = onReady
            self.onPlaying = onPlaying
            self.onEnded = onEnded
            self.onFailed = onFailed
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? String else { return }
            switch body {
            case "playing":
                guard !reportedPlaying else { return }
                reportedPlaying = true
                onPlaying()
            case "ended":
                onEnded()
            case "ready":
                HeroTrailer.log("player ready, asking it to play")
                // From here rather than the page's `onReady` — see the top
                // of the file.
                webView?.evaluateJavaScript("player.mute(); player.playVideo();")
                onReady()
            case let state where state.hasPrefix("state:"):
                // -1 unstarted, 0 ended, 1 playing, 2 paused, 3 buffering,
                // 5 cued — stuck at -1 or 5 means iOS wouldn't start it.
                HeroTrailer.log("player \(state)")
                switch state {
                case "state:1": remote?.isPlaying = true
                case "state:0", "state:2": remote?.isPlaying = false
                default: break
                }
            default:
                HeroTrailer.log("YouTube \(body)")
                // Nothing to tell the reader about a trailer that couldn't
                // play — the backdrop simply stays.
                if body.hasPrefix("error") { onFailed() }
            }
        }

        // A tapped link — the video's title, the YouTube logo — would
        // otherwise load YouTube's site into the hero.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        // …and ones meant for a new window.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url { UIApplication.shared.open(url) }
            return nil
        }
    }

    private static var embedOrigin: String {
        "https://" + (Bundle.main.bundleIdentifier ?? "watchnow.app").lowercased()
    }

    private static func html(for key: String, origin: String) -> String {
        // The key comes from TMDB; keep it to the characters a YouTube id
        // can contain before it goes anywhere near a script.
        let id = key.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        return """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
        <style>html,body{margin:0;padding:0;background:#000;width:100%;height:100%;overflow:hidden}
        #player{position:absolute;inset:0;width:100%;height:100%}</style>
        </head><body><div id="player"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        var captionsCleared = false;
        function onYouTubeIframeAPIReady() {
          window.player = new YT.Player('player', {
            videoId: '\(id)',
            playerVars: { autoplay: 0, mute: 1, controls: 1, fs: 1, playsinline: 1,
                          rel: 0, iv_load_policy: 3,
                          origin: '\(origin)', widget_referrer: '\(origin)' },
            events: {
              onReady: function (e) {
                e.target.mute();
                window.webkit.messageHandlers.trailer.postMessage('ready');
              },
              onStateChange: function (e) {
                window.webkit.messageHandlers.trailer.postMessage('state:' + e.data);
                if (e.data === YT.PlayerState.PLAYING) {
                  // YouTube captions a muted video on its own. Off once at
                  // the start; the CC button brings them back.
                  if (!captionsCleared) {
                    captionsCleared = true;
                    try { e.target.unloadModule('captions'); } catch (_) {}
                  }
                  window.webkit.messageHandlers.trailer.postMessage('playing');
                } else if (e.data === YT.PlayerState.ENDED) {
                  window.webkit.messageHandlers.trailer.postMessage('ended');
                }
              },
              onError: function (e) {
                window.webkit.messageHandlers.trailer.postMessage('error:' + e.data);
              }
            }
          });
        }
        </script></body></html>
        """
    }
}

/// The hero's handle on the player it doesn't own — to pause it while a
/// sheet is over it or it's scrolled away, and carry on after.
@MainActor
final class TrailerRemote {
    weak var webView: WKWebView?
    /// As the player last reported — not just as asked.
    var isPlaying = false

    /// Says why, for the log.
    func pause(_ reason: String) {
        guard let webView else { return }
        HeroTrailer.log("pausing: \(reason)")
        webView.evaluateJavaScript("player.pauseVideo();")
    }

    func resume(_ reason: String) {
        guard let webView else { return }
        HeroTrailer.log("resuming: \(reason)")
        webView.evaluateJavaScript("player.playVideo();")
    }
}

// MARK: - Policy

enum HeroTrailer {

    /// The one switch for the whole feature. YouTube's API policies restrict
    /// drawing over an embedded player, which the hero's scrims and fade
    /// do — this is here so the trailer can be turned off in one place if
    /// that ever needs to be settled the cautious way. Off, the Trailer
    /// action opens the full trailer instead.
    static let isEnabled = true

    /// What the trailer did, in the Xcode console of a debug build — it
    /// fails quietly on purpose, so this is the only place to see why.
    static func log(_ message: String) {
        #if DEBUG
        print("[HeroTrailer] \(message)")
        #endif
    }
}
