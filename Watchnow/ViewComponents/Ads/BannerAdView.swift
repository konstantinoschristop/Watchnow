//
//  BannerAdView.swift
//  Watchnow
//
//  UIViewRepresentable wrapper around AdManagerBannerView (Google Ad Manager).
//  Uses an inline adaptive banner so the ad fills the available width and
//  reports its resolved height back through a binding — the parent can
//  then size itself exactly without reserving phantom space for a failed
//  or pending request.
//
//  ⚠️  Replace AdUnit.banner with your real GAM ad unit ID before
//      submitting to the App Store. The value below is Google's public
//      test unit ID and will only ever serve test creatives.
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
    /// Your AdMob banner unit ID. Format: "ca-app-pub-XXXX/YYYY".
    static let banner = "ca-app-pub-5275868523622377/3482420361"
}

// MARK: - BannerAdView

/// Inline adaptive banner. Zero height until the ad resolves; expands
/// smoothly once a creative is ready. Pass a `@State var adHeight` from
/// the parent and constrain the view's frame to that value.
struct BannerAdView: UIViewRepresentable {

    /// Set to the banner's pixel height once the ad loads.
    /// Stays 0 on error so the parent collapses the reserved space.
    @Binding var adHeight: CGFloat
    /// Container width passed in from SwiftUI layout — avoids the zero-width
    /// issue that occurs when UIScreen.main is read inside a LazyVStack before
    /// the cell has been laid out.
    let width: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(adHeight: $adHeight)
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
        @Binding private var adHeight: CGFloat

        init(adHeight: Binding<CGFloat>) {
            _adHeight = adHeight
        }

        // Ad loaded — tell the parent its real height.
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            let height = bannerView.adSize.size.height
            DispatchQueue.main.async { self.adHeight = height }
        }

        // Failed — keep height at 0 so the parent stays collapsed.
        func bannerView(_ bannerView: BannerView,
                        didFailToReceiveAdWithError error: Error) {
            DispatchQueue.main.async { self.adHeight = 0 }
        }
    }
}
