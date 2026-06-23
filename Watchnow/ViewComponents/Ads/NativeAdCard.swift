//
//  NativeAdCard.swift
//  Watchnow
//
//  A Google "Native advanced" ad rendered as a poster card so it sits
//  naturally inside the horizontal result rows (Most Watched, etc.): the
//  ad's media is the "poster", its headline is the "title", and a small
//  CTA / advertiser line is the meta row. It's always shown through a
//  `NativeAdView` with its asset views registered — required for impressions
//  and clicks to count, and for AdMob policy compliance — and is clearly
//  badged "Ad" (on top of the SDK's own AdChoices overlay).
//
//  In DEBUG it uses Google's public test native unit, so dev builds never
//  serve — or let us click — real ads (which would be invalid activity).
//  The real unit ships in release.
//

import SwiftUI
// `@preconcurrency`: the Mobile Ads SDK isn't Swift-6 annotated, so its types
// (NativeAd, etc.) aren't Sendable. This downgrades the cross-actor "sending"
// diagnostics to warnings — the SDK delivers these callbacks on the main
// thread, which is exactly where we hop with `MainActor.assumeIsolated`.
@preconcurrency import GoogleMobileAds

private enum NativeAdUnit {
    #if DEBUG
    static let id = "ca-app-pub-3940256099942544/3986624511"   // Google test "native advanced"
    #else
    static let id = "ca-app-pub-5275868523622377/7769503325"   // real
    #endif
}

// MARK: - Loader

/// Loads a single native ad and publishes it. `@MainActor` (so it can read
/// the key window when starting a request and mutate its published state),
/// with the SDK's delegate callbacks marked `nonisolated` and hopped back on.
@MainActor
final class NativeAdLoader: NSObject, ObservableObject {

    @Published private(set) var nativeAd: NativeAd?
    @Published private(set) var failed = false

    /// Held so the loader isn't deallocated before the request completes.
    private var adLoader: AdLoader?

    func loadIfNeeded() {
        guard nativeAd == nil, !failed, adLoader == nil else { return }
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        let loader = AdLoader(adUnitID: NativeAdUnit.id,
                              rootViewController: root,
                              adTypes: [.native],
                              options: nil)
        loader.delegate = self
        adLoader = loader
        loader.load(Request())
    }
}

extension NativeAdLoader: NativeAdLoaderDelegate {
    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        MainActor.assumeIsolated {
            self.nativeAd = nativeAd
            self.failed = false
        }
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        MainActor.assumeIsolated {
            self.failed = true
            self.adLoader = nil
        }
    }
}

// MARK: - SwiftUI card

/// Poster-shaped native ad for the result rows. Collapses to nothing if the
/// ad fails to load, so it never leaves a dead slot in the scroll.
struct NativeAdCard: View {

    let posterHeight: CGFloat
    @StateObject private var loader = NativeAdLoader()

    var body: some View {
        Group {
            if let ad = loader.nativeAd {
                NativeAdCardView(nativeAd: ad, posterHeight: posterHeight)
            } else if loader.failed {
                EmptyView()
            } else {
                // Neutral placeholder keeps the row height steady while loading.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: posterHeight)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .onAppear { loader.loadIfNeeded() }
    }
}

// MARK: - NativeAdView (UIKit)

/// Builds a `NativeAdView` laid out like `BottomCard`: media on top (the
/// poster), headline below (the title), and a CTA / advertiser meta line.
private struct NativeAdCardView: UIViewRepresentable {

    let nativeAd: NativeAd
    let posterHeight: CGFloat

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()

        let media = MediaView()
        media.translatesAutoresizingMaskIntoConstraints = false
        media.contentMode = .scaleAspectFill
        media.clipsToBounds = true
        media.layer.cornerRadius = 12
        media.layer.borderWidth = 0.5
        media.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor

        let badge = PaddingLabel()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.text = "Ad"
        badge.font = .systemFont(ofSize: 9, weight: .bold)
        badge.textColor = .black
        badge.backgroundColor = .systemYellow
        badge.layer.cornerRadius = 4
        badge.clipsToBounds = true

        let headline = UILabel()
        headline.translatesAutoresizingMaskIntoConstraints = false
        headline.font = .systemFont(ofSize: 12, weight: .semibold)
        headline.numberOfLines = 2
        headline.textColor = .label
        headline.text = nativeAd.headline

        let meta = UILabel()
        meta.translatesAutoresizingMaskIntoConstraints = false
        meta.font = .systemFont(ofSize: 10, weight: .semibold)
        meta.textColor = .tintColor
        meta.numberOfLines = 1

        adView.addSubview(media)
        media.addSubview(badge)
        adView.addSubview(headline)
        adView.addSubview(meta)

        NSLayoutConstraint.activate([
            media.topAnchor.constraint(equalTo: adView.topAnchor),
            media.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            media.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            media.heightAnchor.constraint(equalToConstant: posterHeight),

            badge.topAnchor.constraint(equalTo: media.topAnchor, constant: 6),
            badge.leadingAnchor.constraint(equalTo: media.leadingAnchor, constant: 6),

            headline.topAnchor.constraint(equalTo: media.bottomAnchor, constant: 6),
            headline.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            headline.trailingAnchor.constraint(equalTo: adView.trailingAnchor),

            meta.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 3),
            meta.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            meta.trailingAnchor.constraint(lessThanOrEqualTo: adView.trailingAnchor),
            meta.bottomAnchor.constraint(lessThanOrEqualTo: adView.bottomAnchor)
        ])

        // Register asset views so the SDK can track viewability / clicks.
        adView.mediaView = media
        media.mediaContent = nativeAd.mediaContent
        adView.headlineView = headline

        if let cta = nativeAd.callToAction {
            meta.text = cta
            adView.callToActionView = meta
        } else if let advertiser = nativeAd.advertiser {
            meta.text = advertiser
            adView.advertiserView = meta
        }

        // Assigning the ad last wires everything up and starts impression
        // tracking.
        adView.nativeAd = nativeAd
        return adView
    }

    func updateUIView(_ uiView: NativeAdView, context: Context) {}
}

// MARK: - Row variant (Search / Watchlist lists)

/// Native ad rendered as a list row matching `ResultRow` (small poster +
/// headline + meta), for the vertical Search and Watchlist lists. Collapses
/// to nothing on failure so it never leaves a blank row.
struct NativeAdRow: View {

    @StateObject private var loader = NativeAdLoader()

    var body: some View {
        Group {
            if let ad = loader.nativeAd {
                NativeAdRowView(nativeAd: ad).frame(height: 120)
            } else if loader.failed {
                EmptyView()
            } else {
                placeholder
            }
        }
        .onAppear { loader.loadIfNeeded() }
    }

    private var placeholder: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.12))
                    .frame(width: 50, height: 12)
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.12))
                    .frame(height: 15)
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.12))
                    .frame(width: 110, height: 12)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Builds a `NativeAdView` laid out like `ResultRow`: small poster on the
/// left, an "AD" badge + headline + CTA/advertiser line in the text column.
private struct NativeAdRowView: UIViewRepresentable {

    let nativeAd: NativeAd

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()

        let media = MediaView()
        media.translatesAutoresizingMaskIntoConstraints = false
        media.contentMode = .scaleAspectFill
        media.clipsToBounds = true
        media.layer.cornerRadius = 10
        media.layer.borderWidth = 0.5
        media.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor

        let badge = PaddingLabel()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.text = "AD"
        badge.font = .systemFont(ofSize: 10, weight: .bold)
        badge.textColor = .secondaryLabel
        badge.layer.borderWidth = 0.5
        badge.layer.borderColor = UIColor.label.withAlphaComponent(0.15).cgColor
        badge.layer.cornerRadius = 9
        badge.clipsToBounds = true

        let headline = UILabel()
        headline.translatesAutoresizingMaskIntoConstraints = false
        headline.font = .systemFont(ofSize: 16, weight: .semibold)
        headline.numberOfLines = 2
        headline.textColor = .label
        headline.text = nativeAd.headline

        let meta = UILabel()
        meta.translatesAutoresizingMaskIntoConstraints = false
        meta.font = .systemFont(ofSize: 12, weight: .semibold)
        meta.textColor = .tintColor
        meta.numberOfLines = 1

        adView.addSubview(media)
        adView.addSubview(badge)
        adView.addSubview(headline)
        adView.addSubview(meta)

        NSLayoutConstraint.activate([
            media.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            media.topAnchor.constraint(equalTo: adView.topAnchor),
            // Min 120×120 points — required by AdMob whenever the creative is
            // a video (test ads always are, so it'd warn otherwise).
            media.widthAnchor.constraint(equalToConstant: 120),
            media.heightAnchor.constraint(equalToConstant: 120),
            media.bottomAnchor.constraint(equalTo: adView.bottomAnchor),

            badge.leadingAnchor.constraint(equalTo: media.trailingAnchor, constant: 12),
            badge.topAnchor.constraint(equalTo: adView.topAnchor),

            headline.leadingAnchor.constraint(equalTo: badge.leadingAnchor),
            headline.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 6),
            headline.trailingAnchor.constraint(equalTo: adView.trailingAnchor),

            meta.leadingAnchor.constraint(equalTo: badge.leadingAnchor),
            meta.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 4),
            meta.trailingAnchor.constraint(lessThanOrEqualTo: adView.trailingAnchor),
            meta.bottomAnchor.constraint(lessThanOrEqualTo: adView.bottomAnchor)
        ])

        adView.mediaView = media
        media.mediaContent = nativeAd.mediaContent
        adView.headlineView = headline

        if let cta = nativeAd.callToAction {
            meta.text = cta
            adView.callToActionView = meta
        } else if let advertiser = nativeAd.advertiser {
            meta.text = advertiser
            adView.advertiserView = meta
        }

        adView.nativeAd = nativeAd
        return adView
    }

    func updateUIView(_ uiView: NativeAdView, context: Context) {}
}

// MARK: - PaddingLabel

/// UILabel with internal padding, for the small "Ad" badge.
private final class PaddingLabel: UILabel {
    private let insets = UIEdgeInsets(top: 2, left: 5, bottom: 2, right: 5)
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}
