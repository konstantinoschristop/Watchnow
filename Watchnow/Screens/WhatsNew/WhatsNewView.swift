//
//  WhatsNewView.swift
//  Watchnow
//
//  The "While You Were Away" briefing sheet.
//
//  Structure is deliberately three fixed bands rather than one long scroll:
//  a pinned header (so the headline never fights the sheet's grab handle), a
//  scrolling card list, and a pinned action bar attached with
//  `safeAreaInset` (so the last card can never hide underneath it).
//
//  Artwork is decorative and never participates in layout: every image sits
//  in an `.overlay` on a sized `Color.clear`, so a wide backdrop cannot push
//  the scroll content wider than the sheet. It decays backdrop → blurred
//  poster → accent wash without the layout changing shape.
//
//  Type uses Dynamic Type text styles throughout, spacing sits on the app's
//  4/8pt rhythm, and colours come from the shared tokens (`Color.accentColor`,
//  `Color(.background)`, `Color(.secondarySystemBackground)`) so the sheet
//  themes with the rest of the app in both appearances.
//
//  All decisions happened upstream; this file only renders.
//

import SwiftUI
import Kingfisher

struct WhatsNewView: View {

    @ObservedObject var vm: WhatsNewViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// YouTube trailer opened in the same in-app web sheet the details
    /// screen uses.
    @State private var trailerLink: TrailerLink?
    @State private var hasAppeared = false
    /// Drives the hero backdrop's slow drift, and the one-shot light sweep
    /// that reveals the hero card.
    @State private var drifting = false
    @State private var sheenSwept = false
    /// Resolved once on appear — `tasteHint` reads the whole watchlist, which
    /// is far too expensive to repeat on every body pass.
    @State private var tasteHint: String?

    private var featured: WatchlistChange? { vm.briefing.first }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 12) {
                    if vm.isSingleChange, let change = featured {
                        focusedCard(change)
                            .entrance(isVisible, index: 0)
                    } else {
                        if let featured {
                            heroCard(featured)
                                .entrance(isVisible, index: 0)
                        }
                        ForEach(Array(vm.briefing.dropFirst().enumerated()), id: \.element.id) { index, change in
                            compactCard(change)
                                .liveScroll(!reduceMotion)
                                .entrance(isVisible, index: index + 1)
                        }
                    }

                    if let overflow = vm.overflowText {
                        Text(overflow)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color(.background))
        .safeAreaInset(edge: .bottom) { actionBar }
        .presentationDragIndicator(.visible)
        .sheet(item: $trailerLink) { link in
            WebViewSheet(url: link.url)
        }
        .onAppear {
            hasAppeared = true
            if !reduceMotion {
                drifting = true
                sheenSwept = true
            }
            if let featured, vm.isSingleChange {
                tasteHint = vm.tasteHint(for: featured)
            }
        }
    }

    /// Entrance animation is opt-out: with Reduce Motion on, everything is
    /// simply already in place.
    private var isVisible: Bool { reduceMotion || hasAppeared }

    // MARK: - Header

    /// Pinned masthead. Instead of a generic wordmark, it opens with the
    /// actual titles that moved — a fanned stack of their posters — so the
    /// sheet is recognisably *yours* before a single word is read. The count
    /// pill replaces a separate subheadline, so nothing says the same thing
    /// twice.
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !vm.isSingleChange {
                posterFan
            }

            VStack(alignment: .leading, spacing: 8) {
                countPill

                Text(vm.headline)
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                if vm.isSingleChange {
                    Text(vm.subheadline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .background(alignment: .top) { headerWash }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vm.headline). \(vm.subheadline)")
        .accessibilityAddTraits(.isHeader)
    }

    /// Up to four changed titles, overlapped and splayed like a hand of
    /// cards. Purely decorative — the same titles are listed below.
    /// They "deal" out: every poster starts squared-up in a pile on the left
    /// and springs into its splayed place, one after another.
    private var posterFan: some View {
        HStack(spacing: -18) {
            ForEach(Array(vm.briefing.prefix(4).enumerated()), id: \.element.id) { index, change in
                fanPoster(change)
                    .rotationEffect(.degrees(dealt ? fanAngle(index) : 0), anchor: .bottom)
                    .offset(x: dealt ? 0 : CGFloat(-index) * 30, y: dealt ? 0 : 6)
                    .scaleEffect(dealt ? 1 : 0.86, anchor: .bottom)
                    .opacity(dealt ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.68)
                        .delay(Double(index) * 0.07), value: dealt)
                    .zIndex(Double(vm.briefing.count - index))
            }
        }
        .padding(.leading, 4)
        .accessibilityHidden(true)
    }

    /// True once the deal-in has been triggered — immediately true under
    /// Reduce Motion, so the fan is simply already laid out.
    private var dealt: Bool { reduceMotion || hasAppeared }

    /// −7°, −2.5°, +2.5°, +7° — a shallow, even splay from the centre.
    private func fanAngle(_ index: Int) -> Double {
        let count = min(vm.briefing.count, 4)
        guard count > 1 else { return 0 }
        let step = 14.0 / Double(count - 1)
        return -7 + step * Double(index)
    }

    private func fanPoster(_ change: WatchlistChange) -> some View {
        poster(change, width: 46, height: 69, radius: 8)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(.systemBackground).opacity(0.9), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.28), radius: 6, y: 3)
    }

    private var countPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkles")
                .font(.caption2.weight(.bold))
                // One bounce on arrival, not a permanent pulse — the hero
                // already carries a continuous drift, and two forever-loops
                // in one view reads as noise.
                .symbolEffect(.bounce, value: dealt)
            Text(vm.totalUnseenCount == 1 ? "1 UPDATE" : "\(vm.totalUnseenCount) UPDATES")
                .font(.caption2.weight(.heavy))
                .fontDesign(.rounded)
                .tracking(1.2)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.accentColor.opacity(0.16)))
        .accessibilityHidden(true)
    }

    /// A soft accent bloom rather than a blurred still — the posters above
    /// already carry the artwork, so a second image would only muddy it.
    private var headerWash: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.20),
                     Color.accentColor.opacity(0.06),
                     Color.clear],
            startPoint: .topLeading,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    // MARK: - Hero card (rank #1)

    /// The most important change gets the front page: its backdrop as the
    /// card, headline copy set directly on the image.
    private func heroCard(_ change: WatchlistChange) -> some View {
        Button {
            vm.open(change)
        } label: {
            ZStack(alignment: .bottomLeading) {
                artworkLayer(change, drift: drifting)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        LinearGradient(stops: [
                            .init(color: .black.opacity(0.05), location: 0),
                            .init(color: .black.opacity(0.50), location: 0.52),
                            .init(color: .black.opacity(0.88), location: 1)
                        ], startPoint: .top, endPoint: .bottom)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    kindChip(change.kind, onImage: true)

                    Text(change.title)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(change.detailText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)

                    if change.hasReminder {
                        reminderBadge(onImage: true)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .overlay { sheen }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(WhatsNewPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: change))
        .accessibilityAddTraits(.isButton)
        .overlay(alignment: .topTrailing) {
            if change.trailerURL != nil {
                trailerButton(change, onImage: true)
                    .padding(12)
            }
        }
    }

    /// A single band of light that sweeps across the hero once, just after
    /// the cards land — the "here it is" flourish.
    private var sheen: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, .white.opacity(0.30), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: geo.size.width * 0.4)
                .rotationEffect(.degrees(20))
                .offset(x: sheenSwept ? geo.size.width * 1.3 : -geo.size.width * 0.6)
                .animation(.easeInOut(duration: 0.95).delay(0.35), value: sheenSwept)
                .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Compact card

    private func compactCard(_ change: WatchlistChange) -> some View {
        Button {
            vm.open(change)
        } label: {
            HStack(spacing: 14) {
                poster(change, width: 56, height: 84, radius: 10)

                VStack(alignment: .leading, spacing: 5) {
                    kindChip(change.kind)

                    Text(change.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(change.detailText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if change.hasReminder {
                        reminderBadge(onImage: false)
                    }
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                cardSurface(cornerRadius: 20)
            }
        }
        .buttonStyle(WhatsNewPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: change))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Focused (single change) card

    /// One change alone gets a portrait treatment: big poster, centred copy,
    /// and the single primary action right underneath it.
    private func focusedCard(_ change: WatchlistChange) -> some View {
        VStack(spacing: 16) {
            poster(change, width: 172, height: 258, radius: 18)
                .padding(.top, 8)

            VStack(spacing: 10) {
                kindChip(change.kind)

                Text(change.title)
                    .font(.title.weight(.heavy))
                    .foregroundStyle(.primary)
                    .lineLimit(3)

                Text(change.detailText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)

            if let tasteHint {
                Label(tasteHint, systemImage: "sparkles")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            if change.hasReminder {
                reminderBadge(onImage: false)
            }

            VStack(spacing: 8) {
                Button {
                    vm.open(change)
                } label: {
                    Text("View title")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .padding(.vertical, 14)
                        .background(LinearGradient.movieNightAccent,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(WhatsNewPressStyle())

                if change.trailerURL != nil {
                    trailerButton(change, onImage: false)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pieces

    /// Decorative artwork that cannot affect layout: the image is an overlay
    /// on a `Color.clear` the caller has already sized, so `scaledToFill`'s
    /// overflow is clipped instead of widening the scroll content.
    /// `drift` gives the image a very slow Ken Burns push so the hero never
    /// sits completely still. It scales the *overlay content* only, inside
    /// the clip, so layout is untouched.
    private func artworkLayer(_ change: WatchlistChange?, drift: Bool = false) -> some View {
        Color.clear
            .overlay {
                Group {
                    if let url = change?.backdropURL {
                        remoteImage(url)
                    } else if let url = change?.posterURL {
                        remoteImage(url)
                            .blur(radius: 26, opaque: true)
                    } else {
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.55),
                                     Color.accentColor.opacity(0.18),
                                     Color(.background)],
                            startPoint: .topLeading,
                            endPoint: .bottom
                        )
                    }
                }
                .scaleEffect(drift ? 1.10 : 1.0)
                .animation(drift ? .easeInOut(duration: 16).repeatForever(autoreverses: true) : nil,
                           value: drift)
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private func remoteImage(_ url: URL) -> some View {
        KFImage.url(url)
            .loadImmediately()
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .fade(duration: 0.3)
            .resizable()
            .scaledToFill()
    }

    @ViewBuilder
    private func poster(_ change: WatchlistChange, width: CGFloat, height: CGFloat, radius: CGFloat) -> some View {
        Group {
            if let url = change.posterURL {
                KFImage.url(url)
                    .downsampling(size: CGSize(width: width * 3, height: height * 3))
                    .loadImmediately()
                    .fromMemoryCacheOrRefresh()
                    .cacheOriginalImage()
                    .fade(duration: 0.25)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.tertiarySystemFill))
                    .overlay {
                        Image(systemName: "film")
                            .font(.system(size: width * 0.28))
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .accessibilityHidden(true)
    }

    /// Card surface. `Color(.background)` is systemGray6, which is the *same*
    /// value as `secondarySystemBackground` in light mode — so cards use the
    /// base system background plus a hairline edge to stay legible as
    /// distinct surfaces in both appearances.
    private func cardSurface(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.systemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            }
    }

    private func kindChip(_ kind: WatchlistChangeKind, onImage: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: kind.icon)
                .font(.caption2.weight(.bold))
            Text(kind.label.uppercased())
                .font(.caption2.weight(.heavy))
                .fontDesign(.rounded)
                .tracking(0.6)
        }
        .lineLimit(1)
        .foregroundStyle(onImage ? Color.white : Color.accentColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            Capsule().fill(onImage ? Color.accentColor : Color.accentColor.opacity(0.16))
        }
        .accessibilityHidden(true)
    }

    private func reminderBadge(onImage: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "bell.fill")
                .font(.caption2.weight(.semibold))
            Text("You asked us to remind you")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(onImage ? Color.white : Color.accentColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            Capsule().fill(onImage ? Color.black.opacity(0.45) : Color.accentColor.opacity(0.16))
        }
        .accessibilityHidden(true)
    }

    /// Secondary action. Sized to the 44pt minimum target in both placements
    /// rather than being a bare tappable label.
    private func trailerButton(_ change: WatchlistChange, onImage: Bool) -> some View {
        Button {
            if let url = change.trailerURL {
                trailerLink = TrailerLink(url: url)
            }
        } label: {
            Group {
                if onImage {
                    Image(systemName: "play.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.black.opacity(0.45)))
                } else {
                    Label("Watch trailer", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(WhatsNewPressStyle())
        .accessibilityLabel("Watch trailer for \(change.title)")
    }

    /// Pinned via `safeAreaInset`, so the scroll view reserves room for it
    /// instead of the last card sliding underneath.
    private var actionBar: some View {
        Button {
            dismiss()
        } label: {
            Text("Done")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 28)
                .padding(.vertical, 13)
                .background { cardSurface(cornerRadius: 14) }
        }
        .buttonStyle(WhatsNewPressStyle())
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }

    /// One spoken sentence per card instead of four disconnected fragments.
    private func accessibilityLabel(for change: WatchlistChange) -> String {
        var parts = [change.kind.label, change.title, change.detailText]
        if change.hasReminder { parts.append("You asked us to remind you") }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Press feedback

/// Matches the gentle press-scale the rest of the app's tappable cards use.
private struct WhatsNewPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Entrance animation

private extension View {
    /// Staggered rise-in with a little overshoot, so the list assembles with
    /// some bounce instead of just fading in. `isVisible` is already true up
    /// front when Reduce Motion is on, so nothing moves.
    func entrance(_ isVisible: Bool, index: Int) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 24)
            .scaleEffect(isVisible ? 1 : 0.94, anchor: .top)
            .animation(.spring(response: 0.5, dampingFraction: 0.62).delay(Double(index) * 0.07),
                       value: isVisible)
    }

    /// Cards shrink and dim slightly as they approach the edges of the
    /// scroll view, so scrolling feels alive rather than like a static list.
    @ViewBuilder
    func liveScroll(_ enabled: Bool) -> some View {
        if enabled {
            scrollTransition(.interactive) { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.55)
                    .scaleEffect(phase.isIdentity ? 1 : 0.93)
            }
        } else {
            self
        }
    }
}

/// URL wrapper so the trailer can drive `.sheet(item:)`.
private struct TrailerLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
