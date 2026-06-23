//
//  MovieNightSetupView.swift
//  Watchnow
//
//  The first screen of Movie Night: a one-screen, all-optional
//  questionnaire. Tap a mood (or several), optionally a length and your
//  streaming services, pick how many of you are watching, and hit
//  "Find our match". A single tap is enough — nothing here is required,
//  so it never becomes the chore the feature is meant to kill.
//
//  Presentation notes: sections stagger in on appear, each chip springs +
//  morphs its glyph to a checkmark when selected, and the "Where" row shows
//  real streaming-service logos so the screen reads as lively, not a form.
//

import SwiftUI
import Kingfisher

struct MovieNightSetupView: View {

    @ObservedObject var vm: MovieNightViewModel

    @State private var selectedMoods: Set<String> = []
    @State private var length: LengthBucket = .any
    @State private var selectedProviders: Set<Int> = []
    @State private var playerCount = 2
    @State private var didPrefill = false
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header.appearStagger(0, appeared)
                moodSection.appearStagger(1, appeared)
                lengthSection.appearStagger(2, appeared)
                whereSection.appearStagger(3, appeared)
                playersSection.appearStagger(4, appeared)
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) { ctaBar }
        .onAppear { appeared = true }
        .task {
            prefillFromPreferences()
            await vm.loadProvidersIfNeeded()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.15))
                Image(systemName: "popcorn.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.accent)
                    .symbolEffect(.bounce, value: appeared)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text("What's everyone in the mood for?")
                    .font(.title2.weight(.semibold))
                Text("Tap what fits — skip the rest. One tap is enough.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Mood

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Mood", icon: "theatermasks.fill")
            FlowLayout(spacing: 8) {
                ForEach(Mood.all) { mood in
                    MNChip(label: mood.label,
                           symbol: mood.symbol,
                           isSelected: selectedMoods.contains(mood.id)) {
                        toggleMood(mood.id)
                    }
                }
            }
        }
    }

    // MARK: - Length

    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("How long", icon: "clock.fill")
            // Equal-width row (not the wrapping FlowLayout) so the three
            // duration chips share one uniform frame, like a segmented control.
            HStack(spacing: 8) {
                ForEach(LengthBucket.allCases) { bucket in
                    MNChip(label: bucket.label,
                           caption: bucket.caption,
                           symbol: bucket.symbol,
                           fillWidth: true,
                           isSelected: length == bucket) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            length = bucket
                        }
                    }
                }
            }
        }
    }

    // MARK: - Where (streaming services)

    private var whereSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Where", icon: "tv.fill")

            if vm.availableProviders.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini)
                    Text("Loading your services…")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            } else {
                // Always show every service; the user's saved ones just come
                // up already selected. (Their picks are remembered on the next
                // "Find our match".)
                if selectedProviders.isEmpty {
                    Text("Which do you have? We'll remember it next time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                FlowLayout(spacing: 8) {
                    ForEach(vm.availableProviders) { provider in
                        providerChip(provider)
                    }
                }
            }
        }
    }

    private func providerChip(_ provider: WatchProvider) -> some View {
        MNChip(label: provider.provider_name,
               logoURL: provider.logoURL,
               isSelected: selectedProviders.contains(provider.provider_id)) {
            toggleProvider(provider.provider_id)
        }
    }

    // MARK: - Players

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("How many of you?", icon: "person.2.fill")
            FlowLayout(spacing: 8) {
                ForEach(1...4, id: \.self) { count in
                    MNChip(label: count == 1 ? "Just me" : "\(count)",
                           symbol: count == 1 ? "person.fill" : "person.2.fill",
                           isSelected: playerCount == count) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            playerCount = count
                        }
                    }
                }
            }
        }
    }

    // MARK: - CTA

    private var ctaBar: some View {
        Button {
            vm.start(with: MovieNightCriteria(moodIDs: selectedMoods,
                                              length: length,
                                              providerIDs: selectedProviders,
                                              playerCount: playerCount))
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "popcorn.fill")
                    .symbolEffect(.bounce, value: appeared)
                Text(playerCount == 1 ? "Find my pick" : "Find our match")
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background { LinearGradient.movieNightAccent }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.accentColor.opacity(0.4), radius: 12, y: 6)
        }
        .buttonStyle(MNPressableStyle())
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        // Soft fade instead of a hard material bar, so the content scrolls
        // away under the button cleanly.
        .background {
            LinearGradient(
                colors: [Color(.background).opacity(0), Color(.background)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.accent)
            Text(text)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func toggleMood(_ id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if selectedMoods.contains(id) { selectedMoods.remove(id) }
            else { selectedMoods.insert(id) }
        }
    }

    private func toggleProvider(_ id: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedProviders.contains(id) { selectedProviders.remove(id) }
            else { selectedProviders.insert(id) }
        }
    }

    /// Pull the user's saved services into local selection the first time
    /// the screen appears (kept off the property initialiser so we don't
    /// touch the main-actor store during view construction).
    private func prefillFromPreferences() {
        guard !didPrefill else { return }
        didPrefill = true
        selectedProviders = Set(StreamingPreferences.providerIDs)
    }
}

// MARK: - Chip

/// Pill chip used across the setup screen. Springs + scales on selection and
/// morphs its leading glyph into a checkmark; provider chips swap the glyph
/// for the service's real logo. Optional caption renders as a smaller second
/// line (used by the length buckets).
private struct MNChip: View {

    let label: String
    var caption: String? = nil
    var symbol: String? = nil
    var logoURL: URL? = nil
    /// When true the chip stretches to fill its container (used for the
    /// equal-width duration row); otherwise it hugs its content.
    var fillWidth: Bool = false
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                leadingIcon
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                    if let caption {
                        Text(caption)
                            .font(.system(size: 11, weight: .regular))
                            .opacity(0.85)
                    }
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: fillWidth ? .infinity : nil)
            .background(
                Capsule().fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? .clear : .primary.opacity(0.08),
                                       lineWidth: 0.5)
            )
            // Full-width chips can't grow (they'd overflow the row), so the
            // selection pop is reserved for the hug-content chips.
            .scaleEffect(isSelected && !fillWidth ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if let logoURL {
            KFImage.url(logoURL)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.accentColor.opacity(0.55))
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(.white)
                            )
                    }
                }
        } else if symbol != nil || isSelected {
            Image(systemName: isSelected ? "checkmark" : (symbol ?? "checkmark"))
                .font(.system(size: 12, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
        }
    }
}

// MARK: - Press style

/// Gentle press-scale for the primary CTA (and the match-screen buttons).
struct MNPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Entrance animation

/// Fades + lifts a section into place with a per-index delay so the screen
/// assembles top-to-bottom when it appears.
private struct AppearStagger: ViewModifier {
    let index: Int
    let appeared: Bool

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.easeOut(duration: 0.45).delay(Double(index) * 0.07), value: appeared)
    }
}

private extension View {
    func appearStagger(_ index: Int, _ appeared: Bool) -> some View {
        modifier(AppearStagger(index: index, appeared: appeared))
    }
}

// MARK: - FlowLayout

/// Minimal wrapping layout: lays subviews left-to-right, wrapping to a new
/// row when the next subview would overflow the proposed width. Used for
/// every chip group on the setup screen.
private struct FlowLayout: Layout {

    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : widest,
                      height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
