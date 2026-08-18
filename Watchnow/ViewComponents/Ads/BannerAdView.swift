//
//  BannerAdView.swift
//  Watchnow
//
//  UIViewRepresentable wrapper around AdMob's BannerView. Uses an anchored
//  adaptive banner so the ad fills the available width and reports its
//  resolved state back through a binding — the parent can then size itself
//  exactly, and collapse completely when a request fails.
//
//  API note: Google Mobile Ads SDK v13 dropped the GAD prefixes in
//  Swift. Relevant renames used here:
//    GADBannerView          → BannerView
//    GADRequest             → Request
//    GADBannerViewDelegate  → BannerViewDelegate
//    GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth
//                           → currentOrientationAnchoredAdaptiveBanner(width:)
//

import SwiftUI
import GoogleMobileAds

// MARK: - Ad unit ID

private enum AdUnit {
    /// Debug builds must never request live inventory — simulator and
    /// dev-device impressions would count as invalid traffic. Mirrors the
    /// split already used by `NativeAdCard`.
    #if DEBUG
    static let banner = "ca-app-pub-3940256099942544/2934735716"   // Google's test banner
    #else
    static let banner = "ca-app-pub-5275868523622377/3482420361"   // production
    #endif
}

// MARK: - Load state

/// Lifecycle of a banner request. The parent needs to tell "still loading"
/// (reserve space so the banner can lay out and mount) apart from "failed"
/// (collapse to nothing rather than leaving a dead grey box on screen).
enum BannerAdState: Equatable {
    case loading
    case loaded(CGFloat)
    case failed

    var height: CGFloat {
        if case .loaded(let h) = self { return h }
        return 0
    }
}

// MARK: - BannerAdView

/// Anchored adaptive banner. Reports load state back to the parent so it can
/// size itself exactly — and disappear entirely when there's no fill.
struct BannerAdView: UIViewRepresentable {

    /// Reflects the request lifecycle: `.loading` → `.loaded(height)` / `.failed`.
    @Binding var state: BannerAdState
    /// Container width passed in from SwiftUI layout — avoids the zero-width
    /// issue that occurs when UIScreen.main is read inside a LazyVStack before
    /// the cell has been laid out.
    let width: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(state: $state)
    }

    func makeUIView(context: Context) -> BannerView {
        let adaptiveSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        let banner      = BannerView(adSize: adaptiveSize)
        banner.adUnitID = AdUnit.banner
        banner.delegate = context.coordinator
        // Resolved here on the main actor — avoids main-actor isolation
        // issues that arise from accessing UIApplication inside the Coordinator.
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding private var state: BannerAdState

        init(state: Binding<BannerAdState>) {
            _state = state
        }

        // Ad loaded — tell the parent its real height.
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            let height = bannerView.adSize.size.height
            DispatchQueue.main.async { self.state = .loaded(height) }
        }

        // No fill / error — the parent collapses the slot entirely.
        func bannerView(_ bannerView: BannerView,
                        didFailToReceiveAdWithError error: Error) {
            DispatchQueue.main.async { self.state = .failed }
        }
    }
}
