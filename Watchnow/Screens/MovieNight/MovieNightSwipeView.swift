//
//  MovieNightSwipeView.swift
//  Watchnow
//
//  The swipe deck. Each player drags the top poster right (keep) or left
//  (pass), or taps the buttons.
//
//  The stack is depth-indexed: every visible card keeps its identity (its
//  deck index), so when the top card is flung the one beneath *rises* into
//  place (scale + offset animate) instead of being re-inserted at full
//  size. The KEEP / NOPE stamp is overlaid on the top card before its drag
//  transform, so it rides the card you're actually deciding on. Each card
//  carries enough to decide on — genres, rating + votes, synopsis, and an
//  "i" button for the full details.
//
//  When the deck runs out for a player we either show the "pass the phone"
//  handoff (more players to go) or jump to the results screen (last player).
//

import SwiftUI
import Kingfisher

struct MovieNightSwipeView: View {

    @ObservedObject var vm: MovieNightViewModel

    /// Live drag translation of the top card.
    @State private var drag: CGSize = .zero
    /// The card currently flying off-screen, drawn on its own layer above the
    /// stack so the deck underneath can advance to the next card instantly.
    @State private var outgoing: Result?
    /// Live offset of the flying-off card.
    @State private var outgoingOffset: CGSize = .zero
    /// Guards against a second swipe firing while a card is flying off.
    @State private var isAnimating = false

    private let swipeThreshold: CGFloat = 110
    /// Top card + this many peeks behind it.
    private let maxVisible = 3

    var body: some View {
        VStack(spacing: 14) {
            header
            progressBar
            deck
            actionButtons
        }
        .padding(.vertical, 8)
        .overlay {
            if vm.awaitingHandoff { handoffOverlay }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if vm.playerCount > 1 {
            Text("Player \(vm.currentPlayer)'s turn")
                .font(.headline)
        } else {
            Text("Keep what you'd watch")
                .font(.headline)
        }
    }

    private var progressBar: some View {
        ProgressView(value: vm.progress)
            .tint(.accentColor)
            .padding(.horizontal, 28)
    }

    // MARK: - Deck

    /// Absolute deck indices currently on screen, top first.
    private var visibleIndices: [Int] {
        guard vm.cardIndex < vm.deck.count else { return [] }
        let end = min(vm.cardIndex + maxVisible, vm.deck.count)
        return Array(vm.cardIndex..<end)
    }

    private var deck: some View {
        ZStack {
            // The upcoming stack, drawn straight from `cardIndex`. Stable
            // per-index zIndex owns the draw order, and the set only ever
            // changes by a front-removal + back-append — so nothing churns.
            ForEach(visibleIndices, id: \.self) { index in
                card(at: index)
            }
            // The just-swiped card flies off here, on its own layer above the
            // entire stack. Because it's decoupled from the deck, advancing
            // `cardIndex` immediately puts the next (already-loaded) card at
            // full size underneath — no peek-gap, no re-index race, and no
            // deeper card flashing a blank placeholder through the top.
            if let outgoing {
                SwipeCard(result: outgoing)
                    .rotationEffect(.degrees(Double(outgoingOffset.width / 18)))
                    .offset(x: outgoingOffset.width, y: outgoingOffset.height * 0.25)
                    .zIndex(1_000_000)
                    .allowsHitTesting(false)
            }
        }
        // Pin the deck area to all available space so it can't collapse and
        // reflow the layout between cards.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func card(at index: Int) -> some View {
        let depth = index - vm.cardIndex
        // Only the frontmost card follows the drag, and only while nothing is
        // mid-fling — so the freshly-promoted top card sits at rest (offset 0,
        // full size) the instant the swiped card hands off to the fly-off layer.
        let isTop = depth == 0 && outgoing == nil
        let live = isTop ? drag : .zero
        SwipeCard(result: vm.deck[index],
                  showInfoButton: isTop,
                  onInfo: { vm.detailTarget = vm.deck[index] })
            // Stamp overlaid *before* the transforms so it rides the card.
            .overlay { if isTop { decisionStamp } }
            .scaleEffect(1 - CGFloat(depth) * 0.04)
            .rotationEffect(.degrees(Double(live.width / 18)))
            .offset(x: live.width, y: CGFloat(depth) * 12 + live.height * 0.25)
            // Stable per-index zIndex: a card's z never changes while it's on
            // screen, so the stack can't reorder mid-animation.
            .zIndex(Double(-index))
            // No fade on insert/remove. The promoted card's *rise* still
            // animates (that's a property change on a persisting card, below),
            // but a newly-appended back card just slots in instead of fading
            // in on top, and the swiped card hands off cleanly to the fly-off
            // layer.
            .transition(.identity)
            .allowsHitTesting(isTop)
            .gesture(dragGesture)
    }

    // MARK: - Decision stamp (pinned to the top card)

    @ViewBuilder
    private var decisionStamp: some View {
        let liking = drag.width > 0
        let strength = min(Double(abs(drag.width)) / swipeThreshold, 1)
        ZStack {
            stamp("KEEP", color: .green, rotation: -18, alignment: .topLeading)
                .opacity(liking ? strength : 0)
            stamp("NOPE", color: .red, rotation: 18, alignment: .topTrailing)
                .opacity(liking ? 0 : strength)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private func stamp(_ text: String, color: Color, rotation: Double, alignment: Alignment) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color, lineWidth: 4))
            .rotationEffect(.degrees(rotation))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        HStack(spacing: 44) {
            circleButton(icon: "xmark", tint: .red) { fling(liked: false) }
            circleButton(icon: "heart.fill", tint: .green) { fling(liked: true) }
        }
        .padding(.bottom, 8)
    }

    private func circleButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 62, height: 62)
                .background(Circle().fill(Color(.secondarySystemBackground)))
                .overlay(Circle().strokeBorder(tint.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isAnimating || vm.cardIndex >= vm.deck.count)
    }

    // MARK: - Handoff

    private var handoffOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.accent)
                Text("Pass to Player \(vm.currentPlayer + 1)")
                    .font(.title2.weight(.bold))
                Text("No peeking at each other's picks!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("I'm ready") {
                    drag = .zero
                    withAnimation { vm.beginNextPlayer() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
            }
            .padding(40)
        }
    }

    // MARK: - Gesture / fling

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isAnimating else { return }
                drag = value.translation
            }
            .onEnded { value in
                guard !isAnimating else { return }
                if value.translation.width > swipeThreshold {
                    fling(liked: true, from: value.translation)
                } else if value.translation.width < -swipeThreshold {
                    fling(liked: false, from: value.translation)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        drag = .zero
                    }
                }
            }
    }

    /// Hand the top card to the fly-off layer at the offset the finger left
    /// it, advance the deck immediately (so the next card is the full-size top
    /// underneath), then animate the handed-off card off the side and drop it.
    /// Nothing in the deck re-indexes mid-flight and nothing blank is ever
    /// revealed, because the next card is already loaded and in place.
    private func fling(liked: Bool, from start: CGSize = .zero) {
        guard !isAnimating, vm.cardIndex < vm.deck.count else { return }
        isAnimating = true

        // Hand the top card to the fly-off layer with no animation, so it
        // appears exactly where the finger left it (a seamless takeover from
        // the dragged card).
        var handoff = Transaction()
        handoff.disablesAnimations = true
        withTransaction(handoff) {
            outgoing = vm.deck[vm.cardIndex]
            outgoingOffset = start
            drag = .zero
        }

        // Advance with a spring so the card behind *eases up* from the peek
        // position into the top slot, instead of snapping. (The earlier
        // "fullscreen then adjusts" was the poster's scaledToFill reflow, now
        // fixed — so this rise animates cleanly.)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            vm.swipe(liked: liked)
        }

        // Slide the handed-off card off the side, slightly faster than the
        // rise so the next card is settling in just as it clears.
        let direction: CGFloat = liked ? 1 : -1
        withAnimation(.easeIn(duration: 0.26)) {
            outgoingOffset = CGSize(width: direction * 900, height: start.height)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.34))
            var clear = Transaction()
            clear.disablesAnimations = true
            withTransaction(clear) {
                outgoing = nil
                outgoingOffset = .zero
                isAnimating = false
            }
        }
    }
}

// MARK: - SwipeCard

/// A single poster card. Bottom gradient carries the title, year, rating +
/// votes, genre pills and a short synopsis; the top corners hold a watchlist
/// badge and (on the top card) an "i" button to the full details.
///
/// Also reused as the hero on the match screen — the winning title shown as
/// "the card that won" — so the payoff matches the deck exactly.
struct SwipeCard: View {

    let result: Result
    var showInfoButton: Bool = false
    var onInfo: () -> Void = {}

    private var isSaved: Bool { WatchlistManager.existsInWatchList(result: result) }
    private var genres: [String] { MovieGenres.names(for: result.genre_ids, limit: 3) }

    var body: some View {
        // The card's size is owned by this dark base alone. The poster is an
        // *overlay* on it (then clipped), so `scaledToFill` can never report
        // its overflowing size to the layout and push the card oversized —
        // that sibling-image sizing was the "appears full then adjusts". The
        // dark fill also means a not-yet-loaded poster reads as a dim card,
        // never a white flash; the image fades in over it.
        Rectangle()
            .fill(Color(white: 0.12))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                KFImage.url(result.getResultPosterURL())
                    // Load as soon as the card is built, not on appear — the
                    // top card is what the user sees first, and without this
                    // it sat on the dark placeholder until a swipe re-rendered
                    // it. (`fromMemoryCacheOrRefresh` alone deferred the
                    // initial download; pairing it with `loadImmediately`, as
                    // PosterImage does, kicks the fetch off right away.)
                    .loadImmediately()
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
            }
            .overlay { gradient }
            .overlay(alignment: .bottomLeading) { info }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .topTrailing) { savedBadge }
            .overlay(alignment: .topLeading) { infoButton }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }

    private var gradient: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.15), .black.opacity(0.92)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var savedBadge: some View {
        if isSaved {
            Label("On your list", systemImage: "bookmark.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(.accent))
                .padding(12)
        }
    }

    @ViewBuilder
    private var infoButton: some View {
        if showInfoButton {
            Button(action: onInfo) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 25))
                    .foregroundStyle(.white, .black.opacity(0.4))
                    .padding(12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More info")
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.getResultTitle())
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            HStack(spacing: 10) {
                let year = result.getReleaseDate(addSeparator: false)
                if !year.isEmpty { Text(year) }
                if let rating = result.vote_average, rating > 0 {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                }
                if let votes = result.vote_count, votes > 0 {
                    Text(Self.formatVotes(votes))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))

            if !genres.isEmpty {
                HStack(spacing: 6) {
                    ForEach(genres, id: \.self) { genre in
                        Text(genre)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.22)))
                    }
                }
            }

            if let overview = result.overview, !overview.isEmpty {
                Text(overview)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(4)
            }
        }
        .padding(18)
    }

    /// Compact vote-count label, e.g. "12k votes".
    private static func formatVotes(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.0fk votes", Double(count) / 1000)
        }
        return "\(count) votes"
    }
}
