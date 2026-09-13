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

    /// Called when the flow is over, however it ended.
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            content
            footer
        }
        .background(Color(.background))
        .task { await vm.start() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            if vm.step != .finish {
                progressDots
            }

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
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .accessibilityElement(children: .combine)
        }
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    private var progressDots: some View {
        HStack(spacing: 7) {
            ForEach(0 ..< OnboardingViewModel.Step.questionCount, id: \.self) { index in
                Capsule()
                    .fill(index <= vm.step.rawValue ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: index == vm.step.rawValue ? 22 : 7, height: 7)
            }
        }
        .animation(reduceMotion ? nil : AppMotion.ease, value: vm.step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(vm.step.rawValue + 1) of \(OnboardingViewModel.Step.questionCount)")
    }

    private var title: String {
        switch vm.step {
        case .services: return "Which services do you have?"
        case .loved:    return "Tap five you've loved"
        case .save:     return "Save three to start"
        case .finish:   return "You're all set"
        }
    }

    private var subtitle: String {
        switch vm.step {
        case .services: return "We'll only suggest what you can actually watch."
        case .loved:    return "However long ago. This is how Watchnow learns your taste."
        case .save:     return "Picked for you from what you just told us."
        case .finish:   return "Your watchlist is ready. We'll tell you when these land."
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            Group {
                switch vm.step {
                case .services: servicesStep
                case .loved:    posterStep(vm.lovedCandidates, isPicked: vm.isLovedPicked, toggle: vm.toggleLoved)
                case .save:     posterStep(vm.saveCandidates, isPicked: vm.isSavePicked, toggle: vm.toggleSave)
                case .finish:   finishStep
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .overlay {
            if vm.isLoading { ProgressView().controlSize(.large) }
        }
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
            ProviderPickerGrid(providers: vm.providers,
                               selectedIDs: vm.selectedProviderIDs,
                               onToggle: vm.toggleProvider)
        }
    }

    private func posterStep(_ candidates: [Result],
                            isPicked: @escaping (Int?) -> Bool,
                            toggle: @escaping (Int) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                  spacing: 16) {
            ForEach(candidates, id: \.id) { result in
                PickablePoster(result: result,
                               isPicked: isPicked(result.id),
                               reduceMotion: reduceMotion) {
                    if let id = result.id { toggle(id) }
                }
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
                    ForEach(vm.savedResults, id: \.id) { result in
                        posterThumb(result)
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
            }
        }
        .padding(.top, 8)
    }

    private func posterThumb(_ result: Result) -> some View {
        KFImage(result.getPosterURL())
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .aspectRatio(2 / 3, contentMode: .fit)
            .clipShape(AppRadius.shape(AppRadius.card))
            .shadow(color: .black.opacity(0.25), radius: 6, y: 4)
    }

    // MARK: - Footer

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
                Text(vm.step == .finish ? "Go to my watchlist" : "Continue")
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

            if vm.step != .finish {
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
                    KFImage(result.getPosterURL())
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(2 / 3, contentMode: .fit)
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
