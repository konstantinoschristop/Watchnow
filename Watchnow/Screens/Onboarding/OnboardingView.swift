//
//  OnboardingView.swift
//  Watchnow
//
//  Three questions and a payoff, shown once.
//
//  The shape is deliberate: it asks for the cheapest possible answers
//  (tap some logos, tap some posters) and spends them immediately, so the
//  session ends on a watchlist with covers in it rather than on an empty
//  screen and a suggestion to go find something. Every step can be skipped
//  and the last screen still lands somewhere useful.
//

import SwiftUI
import Kingfisher

struct OnboardingView: View {

    @StateObject private var vm = OnboardingViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Flipped on shortly after each step mounts, which is what the
    /// staggered reveal animates against. Reset by the `.id(vm.step)` on the
    /// content, so every step cascades in rather than only the first.
    @State private var revealed = false

    /// Called when the flow is over, however it ended.
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            content
            footer
        }
        .background {
            Color(.background)
            AmbientBackdrop(reduceMotion: reduceMotion)
        }
        .task { await vm.start() }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if vm.step == .welcome {
            EmptyView()
        } else {
            questionHeader
        }
    }

    private var questionHeader: some View {
        VStack(spacing: 14) {
            if vm.step.questionIndex != nil {
                progressDots
            }

            stepBadge

            VStack(spacing: 8) {
                Text(title)
                    .appFont(26, weight: .bold, relativeTo: .title)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .appFont(15, relativeTo: .subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .id(vm.step)
            .transition(reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .offset(y: 12)))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .accessibilityElement(children: .combine)
        }
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    private var progressDots: some View {
        let current = vm.step.questionIndex ?? 0
        return HStack(spacing: 7) {
            ForEach(0 ..< OnboardingViewModel.Step.questionCount, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: index == current ? 22 : 7, height: 7)
            }
        }
        .animation(reduceMotion ? nil : AppMotion.springSnappy, value: vm.step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(OnboardingViewModel.Step.questionCount)")
    }

    /// A glyph per step, so the three questions aren't three walls of text
    /// distinguishable only by their headline. It also gives the header
    /// somewhere to land from, which is what makes the step change read as
    /// a change of subject rather than a text swap.
    @ViewBuilder
    private var stepBadge: some View {
        if let icon = stepIcon {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                Circle()
                    .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
                Image(systemName: icon)
                    .appFont(24, weight: .semibold, relativeTo: .title2)
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 60, height: 60)
            .scaleEffect(revealed || reduceMotion ? 1 : 0.6)
            .opacity(revealed ? 1 : 0)
            .animation(reduceMotion
                       ? .easeOut(duration: AppMotion.standard)
                       : .spring(response: 0.55, dampingFraction: 0.6),
                       value: revealed)
            .accessibilityHidden(true)
        }
    }

    private var stepIcon: String? {
        switch vm.step {
        case .services: return "play.tv.fill"
        case .loved:    return "heart.fill"
        case .save:     return "bookmark.fill"
        case .finish:   return "checkmark.seal.fill"
        case .welcome:  return nil
        }
    }

    private var title: String {
        switch vm.step {
        case .welcome:  return ""
        case .services: return "Which services do you have?"
        case .loved:    return "Tap five you've loved"
        case .save:     return "Save three to start"
        case .finish:   return vm.savedResults.isEmpty ? "You're set up" : "You're all set"
        }
    }

    private var subtitle: String {
        switch vm.step {
        case .welcome:  return ""
        case .services: return "We'll only suggest what you can actually watch."
        case .loved:    return "However long ago. This is how Watchnow learns your taste."
        case .save:     return "Picked for you from what you just told us."
        case .finish:
            // Skipping every step is allowed, and telling someone their
            // watchlist is ready over an empty screen would be a small lie.
            return vm.savedResults.isEmpty
                ? "Save anything you come across and we'll tell you when it airs or lands on a service you have."
                : "Your watchlist is ready. We'll tell you when these land."
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            // The header scrolls with the content rather than sitting above
            // it. Pinned, a five-line title at an accessibility size left
            // barely one row of choices visible between it and the footer.
            VStack(spacing: 0) {
                header
                Group {
                    switch vm.step {
                    case .welcome:  welcomeStep
                    case .services: servicesStep
                    case .loved:    posterStep(vm.lovedCandidates, isPicked: vm.isLovedPicked, toggle: vm.toggleLoved)
                    case .save:     posterStep(vm.saveCandidates, isPicked: vm.isSavePicked, toggle: vm.toggleSave)
                    case .finish:   finishStep
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                // Remounting per step is what re-arms the cascade; without
                // it only the first step would ever animate in.
                .id(vm.step)
                .transition(reduceMotion ? .opacity : .onboardingStep)
            }
            .animation(reduceMotion ? .easeInOut(duration: AppMotion.standard)
                                    : .spring(response: 0.45, dampingFraction: 0.86),
                       value: vm.step)
        }
        .scrollBounceBehavior(.basedOnSize)
        .modifier(SoftScrollEdgesModifier())
        .overlay {
            if vm.isLoading { ProgressView().controlSize(.large) }
        }
        .onChange(of: vm.step) { _, _ in arm() }
        .onChange(of: vm.lovedCandidates.count) { _, _ in arm() }
        .onChange(of: vm.saveCandidates.count) { _, _ in arm() }
        .onChange(of: vm.providers.count) { _, _ in arm() }
        .onAppear { arm() }
    }

    /// Drop the reveal and raise it again on the next runloop turn, so the
    /// items animate from their hidden state rather than appearing already
    /// settled. A step whose content is still loading re-arms when it lands.
    private func arm() {
        revealed = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            revealed = true
        }
    }

    /// The door. Says what the app is for in one line, shows the mark, and
    /// gets out of the way — the three questions are the actual work and a
    /// long preamble in front of them would be the thing people skip.
    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                .scaleEffect(revealed || reduceMotion ? 1 : 0.72)
                .opacity(revealed ? 1 : 0)
                .rotationEffect(.degrees(revealed || reduceMotion ? 0 : -10))
                .animation(reduceMotion
                           ? .easeOut(duration: AppMotion.standard)
                           : .spring(response: 0.7, dampingFraction: 0.62),
                           value: revealed)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Welcome to Watchnow")
                    .appFont(30, weight: .bold, relativeTo: .largeTitle)
                    .multilineTextAlignment(.center)
                    .staggeredReveal(index: 4, isRevealed: revealed, reduceMotion: reduceMotion)

                Text("Keep track of what you want to watch, find where it's streaming, and get told the moment it lands.")
                    .appFont(16, relativeTo: .body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .staggeredReveal(index: 7, isRevealed: revealed, reduceMotion: reduceMotion)
            }
            .padding(.top, 28)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 24)

            VStack(spacing: 14) {
                welcomePoint("bell.badge", "Told when a new episode airs")
                    .staggeredReveal(index: 10, isRevealed: revealed, reduceMotion: reduceMotion)
                welcomePoint("play.tv.fill", "Told when it lands on your services")
                    .staggeredReveal(index: 12, isRevealed: revealed, reduceMotion: reduceMotion)
                welcomePoint("sparkles", "A second opinion before you commit")
                    .staggeredReveal(index: 14, isRevealed: revealed, reduceMotion: reduceMotion)
            }
            .padding(.top, 8)

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    private func welcomePoint(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .appFont(17, weight: .semibold, relativeTo: .body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text)
                .appFont(15, relativeTo: .subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var servicesStep: some View {
        if vm.providers.isEmpty && !vm.isLoading {
            // TMDB had nothing for this region, or the request failed. Say
            // so plainly instead of showing an empty box the user will
            // think they broke.
            Text("We couldn't load the services for your region. You can set them later in Settings.")
                .appFont(15, relativeTo: .subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else {
            VStack(spacing: 20) {
                ProviderPickerGrid(providers: vm.providers,
                                   selectedIDs: vm.selectedProviderIDs,
                                   onToggle: vm.toggleProvider,
                                   revealed: revealed,
                                   reduceMotionOverride: reduceMotion)

                servicesNote
            }
        }
    }

    /// Eight chips leave most of the screen empty, and an empty screen is
    /// what "too simple" looks like. This answers the question the step
    /// actually raises — why are you asking me this — which is worth more
    /// than decoration would be.
    private var servicesNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: vm.selectedProviderIDs.isEmpty ? "questionmark.circle" : "checkmark.circle.fill")
                .appFont(17, weight: .semibold, relativeTo: .body)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(vm.selectedProviderIDs.isEmpty
                 ? "We'll use this to tell you when something you saved lands somewhere you can actually watch it."
                 : "^[\(vm.selectedProviderIDs.count) service](inflect: true) selected. We'll tell you the moment a saved title lands on one.")
                .appFont(14, relativeTo: .subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            AppRadius.shape(AppRadius.panel)
                .fill(Color(.secondarySystemBackground).opacity(0.7))
        }
        .animation(reduceMotion ? nil : AppMotion.ease, value: vm.selectedProviderIDs.isEmpty)
        .staggeredReveal(index: 9, isRevealed: revealed, reduceMotion: reduceMotion)
        .accessibilityElement(children: .combine)
    }

    private func posterStep(_ candidates: [Result],
                            isPicked: @escaping (Int?) -> Bool,
                            toggle: @escaping (Int) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                  spacing: 16) {
            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, result in
                PickablePoster(result: result,
                               isPicked: isPicked(result.id),
                               reduceMotion: reduceMotion) {
                    if let id = result.id { toggle(id) }
                }
                .staggeredReveal(index: index, isRevealed: revealed, reduceMotion: reduceMotion)
            }
        }
        // Three covers across is the whole point of the grid; past the
        // accessibility sizes the labels stop fitting beside them. Every
        // title here is reachable uncapped from its details screen later.
        .artworkTypeClamp()
    }

    // MARK: - Finish

    private var finishStep: some View {
        VStack(spacing: 22) {
            if !vm.savedResults.isEmpty {
                HStack(spacing: 12) {
                    ForEach(Array(vm.savedResults.enumerated()), id: \.element.id) { index, result in
                        posterThumb(result)
                            .dealtCard(index: index, isDealt: revealed, reduceMotion: reduceMotion)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Saved: " + vm.savedResults
                    .map { $0.getResultTitle() }.joined(separator: ", "))
            }

            // Renders nothing at all on a device without Foundation Models,
            // which is the point — Coach is never advertised where it can't
            // run. See `MovieCoachService.availability`.
            if vm.coachContext != nil {
                MovieCoachView(context: vm.coachContext)
                    .padding(.horizontal, -20)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed || reduceMotion ? 0 : 20)
                    .animation(reduceMotion
                               ? .easeOut(duration: AppMotion.standard)
                               : .spring(response: 0.5, dampingFraction: 0.82).delay(0.42),
                               value: revealed)
            }
        }
        .padding(.top, 8)
    }

    private func posterThumb(_ result: Result) -> some View {
        // The aspect ratio is carried by the shape underneath, never by the
        // image — see the note in `PickablePoster`.
        Rectangle()
            .fill(Color(.secondarySystemBackground))
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay {
                KFImage(result.getPosterURL())
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(AppRadius.shape(AppRadius.card))
            .shadow(color: .black.opacity(0.25), radius: 6, y: 4)
    }

    // MARK: - Footer

    private var primaryActionTitle: String {
        switch vm.step {
        case .welcome: return "Get started"
        case .finish:  return "Go to my watchlist"
        default:       return "Continue"
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if let progress = vm.progressText {
                Text(progress)
                    .appFont(13, weight: .semibold, relativeTo: .footnote)
                    .foregroundStyle(vm.canContinue ? Color.accentColor : .secondary)
                    .accessibilityLabel("\(progress) chosen")
            }

            Button {
                if vm.step == .finish { onFinish() } else { Task { await vm.advance() } }
            } label: {
                Text(primaryActionTitle)
                    .appFont(17, weight: .semibold, relativeTo: .body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: AppTouch.minTarget)
                    .background {
                        AppRadius.shape(AppRadius.panel)
                            .fill(vm.canContinue ? Color.accentColor : Color.secondary.opacity(0.35))
                    }
            }
            .buttonStyle(.plain)
            .disabled(!vm.canContinue)
            // A small lift the moment the step is satisfied, so the button
            // announces itself rather than quietly changing colour.
            .scaleEffect(vm.canContinue && !reduceMotion ? 1.02 : 1)
            .animation(reduceMotion ? nil : AppMotion.springBouncy, value: vm.canContinue)

            if vm.step != .finish && vm.step != .welcome {
                Button {
                    Task { await vm.advance(skipping: true) }
                } label: {
                    Text("Skip")
                        .appFont(16, weight: .medium, relativeTo: .body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: AppTouch.minTarget)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Color(.background))
    }
}

// MARK: - PickablePoster

/// A cover that can be tapped on and off. Selection is carried by a tint, a
/// checkmark and a lift, not by any one of them alone — a single blue ring
/// is invisible against half the posters in a trending grid.
private struct PickablePoster: View {

    let result: Result
    let isPicked: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    // The aspect ratio is carried by the `Rectangle`, with
                    // the artwork layered on top — not the other way round.
                    // An unloaded `KFImage` reports a zero ideal size, so in
                    // a `LazyVGrid` cell (where the proposed height is
                    // unspecified) `.fit` on the image itself has nothing to
                    // derive a height from and the whole tile collapses
                    // until the art decodes. A shape accepts any proposal,
                    // so the slot is the right size from the first frame.
                    // Same reasoning as `WatchlistPosterCell`.
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .aspectRatio(2 / 3, contentMode: .fit)
                        .overlay {
                            KFImage(result.getPosterURL())
                                .resizable()
                                .scaledToFill()
                        }
                        .clipShape(AppRadius.shape(AppRadius.card))
                        .overlay {
                            AppRadius.shape(AppRadius.card)
                                .strokeBorder(isPicked ? Color.accentColor : .white.opacity(0.08),
                                              lineWidth: isPicked ? 3 : 0.5)
                        }
                        .overlay {
                            if isPicked {
                                AppRadius.shape(AppRadius.card)
                                    .fill(Color.accentColor.opacity(0.22))
                            }
                        }

                    if isPicked {
                        Image(systemName: "checkmark.circle.fill")
                            .appFont(18, weight: .bold, relativeTo: .body)
                            .foregroundStyle(.white, Color.accentColor)
                            .padding(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(isPicked && !reduceMotion ? 1.03 : 1)

                Text(result.getResultTitle())
                    .appFont(12, weight: .medium, relativeTo: .caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : AppMotion.springSnappy, value: isPicked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(result.getResultTitle())
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
    }
}
