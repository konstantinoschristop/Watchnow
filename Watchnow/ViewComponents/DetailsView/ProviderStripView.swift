//
//  ProviderStripView.swift
//  Watchnow
//
//  "Available on", as one compact row:
//
//      Available on  [N] [D] [A] [+2]      JustWatch ›
//
//  The question this answers on arrival is "can I watch it on something I
//  have?", and a row of logos answers it at a glance. The full breakdown —
//  stream, rent and buy, each provider named — is one tap away in a sheet
//  that reuses `WatchProviderView`, so nothing the old card showed is gone;
//  it just no longer costs a third of the screen before the synopsis.
//
//  Which logos make the row:
//   - Subscription services when there are any. Mixing in rentals would
//     make "it's on Apple TV" ambiguous between included and £3.49.
//   - Otherwise rentals, otherwise purchases — and the caption says which.
//   - Services the user has told us they pay for go first, with a tick.
//   - As many as fit; the rest are counted in the "+N" chip. The count is
//     every distinct provider not shown, across all three modes, because
//     that is what the sheet will reveal.
//
//  JustWatch stays named on the row itself: TMDB licenses this data on the
//  condition that JustWatch is credited wherever it is shown.
//

import SwiftUI

struct ProviderStripView: View {

    let flatrates: [Flatrate]
    let rent: [Flatrate]
    let buy: [Flatrate]
    let justWatchURL: URL?

    @State private var showsAll = false
    /// Logos pop in one after another as the strip arrives.
    @State private var logosShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var logoSize: CGFloat = 34

    var body: some View {
        Button {
            showsAll = true
        } label: {
            ViewThatFits(in: .horizontal) {
                ForEach([4, 3, 2, 1], id: \.self) { count in
                    strip(maxLogos: count)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(AppRadius.shape(AppRadius.hero))
            .detailsCard(radius: AppRadius.hero)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        // The strip only exists once the providers have loaded, so this is
        // the data arriving.
        .onAppear { logosShown = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(String(localized: "Shows every way to watch", comment: "Accessibility hint on the Available on row"))
        .accessibilityAddTraits(.isButton)
        .coversDetailsPage(showsAll)
        .sheet(isPresented: $showsAll) {
            ProvidersSheet(flatrates: flatrates,
                           rent: rent,
                           buy: buy,
                           justWatchURL: justWatchURL)
        }
    }

    // MARK: - Row

    private func strip(maxLogos: Int) -> some View {
        let visible = Array(featured.items.prefix(maxLogos))
        let hidden = distinctProviderCount - visible.count

        return HStack(spacing: 10) {
            Text("Available on", comment: "Details section: streaming services carrying the title")
                .appFont(15, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize()

            HStack(spacing: 6) {
                ForEach(Array(visible.enumerated()), id: \.element.providerID) { index, provider in
                    logo(provider)
                        .scaleEffect(logosShown || reduceMotion ? 1 : 0.4)
                        .opacity(logosShown ? 1 : 0)
                        .animation(reduceMotion ? .easeOut(duration: AppMotion.standard)
                                                : .spring(response: 0.45, dampingFraction: 0.6).delay(0.12 + Double(index) * 0.06),
                                   value: logosShown)
                }
                if hidden > 0 {
                    Text(verbatim: "+\(hidden)")
                        .appFont(13, weight: .semibold, relativeTo: .footnote)
                        .foregroundStyle(Color.accentColor)
                        .frame(minWidth: logoSize, minHeight: logoSize)
                        .background(Color.accentColor.opacity(0.10),
                                    in: AppRadius.shape(AppRadius.small))
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Text(caption)
                    .appFont(11, weight: .medium, relativeTo: .caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
                Image(systemName: "chevron.right")
                    .appFont(12, weight: .semibold, relativeTo: .footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func logo(_ provider: Flatrate) -> some View {
        if let path = provider.logoPath {
            RemoteImage(url: URL(string: API.Common.imageUrl(imageId: path, width: .poster)))
                .frame(width: logoSize, height: logoSize)
                .clipShape(AppRadius.shape(AppRadius.small))
                .overlay {
                    AppRadius.shape(AppRadius.small)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
                // A tick on the services the user pays for — the same
                // answer as the hero's "On your …" pill, at the logo.
                .overlay(alignment: .bottomTrailing) {
                    if let id = provider.providerID, ownedIDs.contains(id) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .background(Circle().fill(.white).padding(1))
                            .offset(x: 4, y: 4)
                            .accessibilityHidden(true)
                    }
                }
        }
    }

    private var ownedIDs: Set<Int> {
        Set(StreamingPreferences.providerIDs)
    }

    // MARK: - Data

    private enum Mode { case stream, rent, buy }

    /// The one mode the row's logos come from — see the file header.
    private var featured: (mode: Mode, items: [Flatrate]) {
        let mode: Mode
        let items: [Flatrate]
        if !flatrates.isEmpty {
            (mode, items) = (.stream, flatrates)
        } else if !rent.isEmpty {
            (mode, items) = (.rent, rent)
        } else {
            (mode, items) = (.buy, buy)
        }

        let owned = Set(StreamingPreferences.providerIDs)
        let withLogos = items.filter { $0.logoPath != nil && $0.providerID != nil }
        // Stable: TMDB already orders by display priority, and that order
        // is kept within each half.
        let sorted = withLogos.filter { owned.contains($0.providerID!) }
            + withLogos.filter { !owned.contains($0.providerID!) }
        return (mode, sorted)
    }

    private var distinctProviderCount: Int {
        Set((flatrates + rent + buy).compactMap(\.providerID)).count
    }

    /// The source, plus the mode when it isn't the one people assume.
    private var caption: String {
        switch featured.mode {
        case .stream:
            return "JustWatch"
        case .rent:
            return String(localized: "Rent", comment: "Where to watch: available to rent") + " · JustWatch"
        case .buy:
            return String(localized: "Buy", comment: "Where to watch: available to buy") + " · JustWatch"
        }
    }

    private var accessibilityText: String {
        var seen = Set<Int>()
        let names = (flatrates + rent + buy).compactMap { provider -> String? in
            guard let id = provider.providerID, seen.insert(id).inserted else { return nil }
            return provider.providerName
        }
        let heading = String(localized: "Available on", comment: "Details section: streaming services carrying the title")
        return heading + ": " + names.formatted(.list(type: .and))
    }
}

// MARK: - Sheet

/// Every way to watch, grouped by stream / rent / buy — the card the strip
/// replaced, unchanged, so the detail is still there for whoever wants it.
private struct ProvidersSheet: View {

    let flatrates: [Flatrate]
    let rent: [Flatrate]
    let buy: [Flatrate]
    let justWatchURL: URL?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                WatchProviderView(flatrates: flatrates,
                                  rent: rent,
                                  buy: buy,
                                  justWatchURL: justWatchURL)
                    .padding(.vertical, 12)
            }
            .background(Color(.background))
            .navigationTitle(Text("Available on", comment: "Details section: streaming services carrying the title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
