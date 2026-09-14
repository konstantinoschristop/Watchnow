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
//  The look is deliberate too, and it is a reaction to what this screen
//  used to be. Four of the five steps were the same layout — a centred
//  circle badge, a big title, a subtitle, then content — on a near-white
//  background, with a header that ate 45% of the viewport and left one and
//  a half rows of a thirty-poster grid visible. It was clean and it was
//  anonymous: nothing on screen said the app was about films.
//
//  So: the flow runs dark over a wall of real poster art that never stops
//  drifting, the three question headers collapse into a single compact row
//  so the grid gets the screen, and the steps push sideways rather than
//  cross-fading. See `OnboardingMotion.swift` for the pieces.
//

import SwiftUI
import Kingfisher

struct OnboardingView: View {

    @StateObject private var vm = OnboardingViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Flipped on once the step's push has landed, which is what the
    /// staggered cascade animates against. Reset by `arm()` on every step
    /// change, so every step cascades in rather than only the first.
    @State private var revealed = false

    /// Invalidates an in-flight `arm()`. Two can overlap easily — the step
    /// changes, then its candidates land 200ms later — and without this the
    /// earlier one's delayed `revealed = true` could fire after the later
    /// one has already reset it, stranding the cascade half-played.
    @State private var armToken = 0

    /// Called when the flow is over, however it ended.
    let onFinish: () -> Void

    // MARK: - Palette
    //
    // Written out rather than taken from the semantic tokens. The flow
    // forces a dark appearance over the poster wall regardless of the
    // device's setting, so "secondary label" resolving against the system
    // would be the wrong grey half the time.

    private let secondaryInk = Color.white.opacity(0.74)
    private let tertiaryInk = Color.white.opacity(0.55)

    /// A pool of shadow under a block of type, so a headline is legible
    /// whichever cover the wall happens to have drifted behind it.
    ///
    /// Local rather than global on purpose. The welcome and payoff screens
    /// are the two the wall is *for* — turning `dim` up far enough to
    /// guarantee contrast under a Simpsons poster would flatten the whole
    /// screen to get one paragraph readable. A title card over a film still
    /// is exactly this: the still stays bright, the type carries its own
    /// shadow.
    private var titleHalo: some View {
        Ellipse()
            .fill(RadialGradient(colors: [.black.opacity(0.78), .black.opacity(0.4), .clear],
                                 center: .center, startRadius: 10, endRadius: 230))
            .scaleEffect(x: 1.9, y: 1.5)
            .allowsHitTesting(false)
    }

    /// A pane you can see the wall through. Not `.ultraThinMaterial`: a
    /// material over a backdrop that redraws every frame re-blurs every
    /// frame, and the wall is doing exactly that underneath. A flat
    /// translucent fill over the scrim reads the same and costs nothing.
    /// See `OnboardingSurface` for how its alpha was arrived at.
    private func glass(_ radius: CGFloat) -> some View {
        AppRadius.shape(radius)
            .fill(OnboardingSurface.glass)
            .overlay {
                AppRadius.shape(radius)
                    .strokeBorder(OnboardingSurface.edge, lineWidth: 1)
            }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            progressRail
            content
            footer
        }
        .background {
            PosterWall(posters: vm.wallPosters,
                       dim: backdropDim,
                       parallax: backdropParallax,
                       reduceMotion: reduceMotion)
        }
        // The whole flow is dark whatever the device is set to, because the
        // wall behind it is. Scoped to this subtree rather than set as a
        // preferred scheme, so it never reaches out of the cover.
        .environment(\.colorScheme, .dark)
        .tint(.white)
        .task { await vm.start() }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: vm.step)
    }

    /// How hard the wall is held back on this step. The question steps push
    /// it right down — a wall of posters behind a grid of posters is two
    /// things competing for the same attention — and the two screens that
    /// are mostly type let it come up.
    private var backdropDim: Double {
        switch vm.step {
        case .welcome:      return 0.42
        case .services:     return 0.74
        case .loved, .save: return 0.87
        case .finish:       return 0.62
        }
    }

    /// A fraction of the step's own travel, so the wall reads as sitting
    /// further back than the content sliding across it.
    private var backdropParallax: CGFloat { CGFloat(vm.step.rawValue) * -18 }

    // MARK: - Progress rail

    /// Three tracks, pinned above the scroll view.
    ///
    /// Pinned because it is 4pt tall and cannot push anything off screen —
    /// the *text* header still scrolls, for the reason recorded on
    /// `content`. And the fill is continuous rather than per-step: it
    /// advances as picks are made, so tapping a fifth poster visibly
    /// completes the track rather than only unlocking a button somewhere
    /// below the fold.
    private var progressRail: some View {
        HStack(spacing: 7) {
            ForEach(0 ..< OnboardingViewModel.Step.questionCount, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: 5)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [Color.accentColor, WatchnowBrand.gold],
                                                 startPoint: .leading, endPoint: .trailing))
                            .shadow(color: Color.accentColor.opacity(0.7), radius: 6)
                            .scaleEffect(x: railFill(index), y: 1, anchor: .leading)
                    }
            }
        }
        .animation(reduceMotion ? nil : AppMotion.springSoft, value: vm.step)
        .animation(reduceMotion ? nil : AppMotion.springSoft, value: vm.selectedProviderIDs.count)
        .animation(reduceMotion ? nil : AppMotion.springSoft, value: vm.lovedPickIDs.count)
        .animation(reduceMotion ? nil : AppMotion.springSoft, value: vm.savePickIDs.count)
        .frame(maxWidth: 240)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(railAccessibilityLabel)
    }

    /// 0…1 for one track. The active one reports how far through its own
    /// question the user is, with a floor so an untouched active track is
    /// still visibly the one in play.
    private func railFill(_ index: Int) -> CGFloat {
        guard let current = vm.step.questionIndex else {
            // Welcome promises three steps; finish shows all three kept.
            return vm.step == .finish ? 1 : 0
        }
        if index < current { return 1 }
        if index > current { return 0 }

        switch vm.step {
        case .services:
            return vm.selectedProviderIDs.isEmpty ? 0.1 : 1
        case .loved:
            return fraction(vm.lovedPickIDs.count, of: OnboardingViewModel.requiredLoved)
        case .save:
            return fraction(vm.savePickIDs.count, of: OnboardingViewModel.requiredSaves)
        default:
            return 0
        }
    }

    private func fraction(_ count: Int, of required: Int) -> CGFloat {
        max(0.1, min(1, CGFloat(count) / CGFloat(required)))
    }

    /// `LocalizedStringKey`, not `String`, and that distinction is the whole
    /// point: `accessibilityLabel` and `Text` both have a
    /// `LocalizedStringKey` overload that the string extractor can see, and
    /// a `String` overload that it cannot. Returning `String` here quietly
    /// dropped `"Step %lld of %lld"` — which had a translation — out of the
    /// catalogue on the next build.
    private var railAccessibilityLabel: LocalizedStringKey {
        guard let current = vm.step.questionIndex else {
            return vm.step == .finish ? "Setup complete" : "Three steps to set up"
        }
        return "Step \(current + 1) of \(OnboardingViewModel.Step.questionCount)"
    }

    // MARK: - Content

    /// Anchor for `content`'s scroll reset. See `onChange(of: vm.step)`.
    private static let topAnchor = "onboarding.top"

    @ViewBuilder
    private var content: some View {
        ScrollViewReader { proxy in
        ScrollView {
            // A `ZStack`, not a `VStack`: during a push both steps are
            // alive at once, and stacked vertically that briefly doubles
            // the scroll view's content height and jolts the offset. Laid
            // on top of each other they simply cross.
            ZStack(alignment: .top) {
                Color.clear
                    .frame(height: 0)
                    .id(Self.topAnchor)

                stepBody
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity)
                    // Remounting per step is what re-arms the cascade;
                    // without it only the first step would ever animate in.
                    .id(vm.step)
                    .transition(.cinematicPush(reduceMotion: reduceMotion))
            }
            .animation(reduceMotion ? .easeInOut(duration: AppMotion.standard)
                                    : .spring(response: 0.44, dampingFraction: 0.88),
                       value: vm.step)
        }
        .scrollBounceBehavior(.basedOnSize)
        .modifier(SoftScrollEdgesModifier())
        .overlay {
            if vm.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
        }
        .onChange(of: vm.step) { _, _ in
            arm(afterPush: true)
            // Each step starts at its own top. The scroll view outlives the
            // step inside it, so without this an offset earned on one step
            // is inherited by the next — at an accessibility text size the
            // welcome screen scrolls, and tapping Get started then opened
            // the services question already scrolled past its own header
            // with the first chip clipped.
            //
            // A `ScrollViewReader` rather than `scrollPosition(_:)`: the
            // binding form writes state as the user drags, which would
            // re-render the whole step — thirty poster cells included — on
            // every frame of every scroll. The proxy only ever scrolls; it
            // observes nothing.
            proxy.scrollTo(Self.topAnchor, anchor: .top)
        }
        // Each guarded on the step that actually displays that list. The
        // trending fetch moved to launch, so it and the provider fetch both
        // land while the *welcome* step is on screen — and un-guarded they
        // re-armed the cascade there, blinking the logo, headline and all
        // three bullet points out and back in, once per response, while the
        // user was reading them.
        .onChange(of: vm.lovedCandidates.count) { _, _ in
            if vm.step == .loved { arm(afterPush: false) }
        }
        .onChange(of: vm.saveCandidates.count) { _, _ in
            if vm.step == .save { arm(afterPush: false) }
        }
        .onChange(of: vm.providers.count) { _, _ in
            if vm.step == .services { arm(afterPush: false) }
        }
        .onAppear { arm(afterPush: false) }
        }
    }

    /// Drop the reveal and raise it again shortly after, so the items
    /// animate from their hidden state rather than appearing already
    /// settled.
    ///
    /// `afterPush` is the whole trick behind the step transition. The
    /// previous directional slide was abandoned because the grid cascaded
    /// *while* the container was still travelling, which left posters
    /// scattered mid-flight. Waiting out the push first turns the two
    /// competing effects into one sequence.
    private func arm(afterPush: Bool) {
        revealed = false
        armToken &+= 1
        let token = armToken
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(afterPush ? 210 : 30))
            guard token == armToken else { return }
            revealed = true
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch vm.step {
        case .welcome:
            welcomeStep
        case .services:
            question { servicesStep }
        case .loved:
            question {
                posterStep(vm.lovedCandidates, isPicked: vm.isLovedPicked, toggle: vm.toggleLoved)
            }
        case .save:
            question {
                posterStep(vm.saveCandidates, isPicked: vm.isSavePicked, toggle: vm.toggleSave)
            }
        case .finish:
            finishStep
        }
    }

    // MARK: - Question steps

    /// The header and its step's content.
    ///
    /// The header scrolls with the content rather than sitting above it —
    /// pinned, a five-line title at an accessibility size left barely one
    /// row of choices visible between it and the footer. It recedes as it
    /// goes, using a transform-only `scrollTransition` so a scroll costs no
    /// view updates and no offscreen passes.
    private func question<Content: View>(@ViewBuilder _ body: () -> Content) -> some View {
        VStack(spacing: 22) {
            questionHeader
                .modifier(RecedingHeader(reduceMotion: reduceMotion))
            body()
        }
    }

    /// Icon beside the words, not above them.
    ///
    /// This is the single biggest change to the layout. Stacked and centred,
    /// the badge, title and subtitle came to roughly 400pt — on a 402×874
    /// phone that is 45% of the viewport spent restating a question the user
    /// answers in the other 55%. Laid out as a row it comes to about 80, and
    /// the poster grid gets two and a half rows instead of one and a half.
    private var questionHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            stepBadge

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(22, weight: .bold, relativeTo: .title2)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .appFont(14, relativeTo: .subheadline)
                    .foregroundStyle(secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    /// A glyph per step, so the three questions aren't three walls of text
    /// distinguishable only by their headline. It also gives the header
    /// somewhere to land from, which is what makes the step change read as
    /// a change of subject rather than a text swap.
    private var stepBadge: some View { badge(size: 48, glyph: 20) }

    @ViewBuilder
    private func badge(size: CGFloat, glyph: CGFloat) -> some View {
        if let icon = stepIcon {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.22))
                Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                Image(systemName: icon)
                    .appFont(glyph, weight: .semibold, relativeTo: .title3)
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: revealed)
            }
            .frame(width: size, height: size)
            .shadow(color: Color.accentColor.opacity(0.55), radius: 12)
            .scaleEffect(revealed || reduceMotion ? 1 : 0.5)
            .opacity(revealed ? 1 : 0)
            .rotationEffect(.degrees(revealed || reduceMotion ? 0 : -30))
            .animation(reduceMotion
                       ? .easeOut(duration: AppMotion.standard)
                       : .spring(response: 0.5, dampingFraction: 0.58),
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

    /// See the note on `railAccessibilityLabel` for why these are keys
    /// rather than strings.
    private var title: LocalizedStringKey {
        switch vm.step {
        case .welcome:  return ""
        case .services: return "Which services do you have?"
        case .loved:    return "Tap five you've loved"
        case .save:     return "Save three to start"
        case .finish:
            switch vm.payoff {
            case .nothingSaved: return "You're set up"
            case .readyToWatch: return "Ready to watch"
            default:            return "You're all set"
            }
        }
    }

    private var subtitle: LocalizedStringKey {
        switch vm.step {
        case .welcome:  return ""
        case .services: return "We'll only suggest what you can actually watch."
        case .loved:    return "However long ago. This is how Watchnow learns your taste."
        case .save:
            return vm.lovedPickIDs.isEmpty
                ? "In cinemas, airing this week, and trending right now."
                : "On now, and matched to the five you just picked."
        case .finish:
            // Never a flat promise. The app has exactly two automatic
            // alerts and both fire on a change — a next episode airing, or
            // a title *newly* reaching a service the user has — so neither
            // can fire for something that was already streaming when it was
            // saved. Since step three now leads with titles that are
            // streaming right now, "we'll tell you when these land" was
            // usually a promise about an event that could never happen.
            // `OnboardingViewModel.payoff` works out which sentence is
            // actually true.
            switch vm.payoff {
            case .nothingSaved:
                return "Save anything you come across and we'll tell you when it airs or lands on a service you have."
            case .readyToWatch:
                return "Every one of these is on a service you have. Start tonight."
            case .landingLater:
                return "Saved. We'll tell you the moment the new releases reach a service you have."
            case .episodesAhead:
                return "Saved. We'll tell you the day the next episode airs."
            case .mixed:
                return "Saved. We'll tell you when a new episode airs, or when one reaches a service you have."
            }
        }
    }

    // MARK: - Welcome

    /// The door. Says what the app is for in one line, shows the mark, and
    /// gets out of the way — the three questions are the actual work and a
    /// long preamble in front of them would be the thing people skip.
    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)

            ZStack {
                // A pool of light under the mark, so the logo sits *in* the
                // scene rather than on top of a photograph of one.
                Circle()
                    .fill(RadialGradient(colors: [Color.accentColor.opacity(0.5), .clear],
                                         center: .center, startRadius: 4, endRadius: 130))
                    .frame(width: 260, height: 260)
                    .scaleEffect(revealed || reduceMotion ? 1 : 0.6)
                    .opacity(revealed ? 1 : 0)

                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
                    .breathing(reduceMotion: reduceMotion, travel: 7, period: 3.8)
            }
            .scaleEffect(revealed || reduceMotion ? 1 : 0.72)
            .opacity(revealed ? 1 : 0)
            .rotationEffect(.degrees(revealed || reduceMotion ? 0 : -10))
            .animation(reduceMotion
                       ? .easeOut(duration: AppMotion.standard)
                       : .spring(response: 0.72, dampingFraction: 0.62),
                       value: revealed)
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Welcome to Watchnow")
                    .appFont(30, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .staggeredReveal(index: 4, isRevealed: revealed, reduceMotion: reduceMotion)

                Text("Keep track of what you want to watch, find where it's streaming, and get told the moment it lands.")
                    .appFont(16, relativeTo: .body)
                    .foregroundStyle(secondaryInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .staggeredReveal(index: 7, isRevealed: revealed, reduceMotion: reduceMotion)
            }
            .padding(.top, 20)
            .background { titleHalo }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 28)

            VStack(spacing: 16) {
                welcomePoint("bell.badge", "Told when a new episode airs")
                    .staggeredReveal(index: 10, isRevealed: revealed, reduceMotion: reduceMotion)
                welcomePoint("play.tv.fill", "Told when it lands on your services")
                    .staggeredReveal(index: 12, isRevealed: revealed, reduceMotion: reduceMotion)
                welcomePoint("sparkles", "A second opinion before you commit")
                    .staggeredReveal(index: 14, isRevealed: revealed, reduceMotion: reduceMotion)
            }
            .padding(18)
            .background { glass(AppRadius.hero) }

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity)
        // The welcome screen is the one step that should never scroll — it
        // is a poster, not a form. Holding it to the viewport keeps the
        // three points pinned above the button instead of drifting.
        .frame(minHeight: welcomeMinimumHeight)
    }

    /// Roughly the viewport left between the rail and the footer. Deliberately
    /// approximate: `.frame(minHeight:)` only ever grows the step, so an
    /// under-estimate loses a little of the intended balance while an
    /// over-estimate would make a screen with nothing to scroll scrollable.
    private var welcomeMinimumHeight: CGFloat { 560 }

    private func welcomePoint(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .appFont(16, weight: .semibold, relativeTo: .body)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background {
                    Circle().fill(Color.accentColor.opacity(0.28))
                }
                .accessibilityHidden(true)

            Text(text)
                .appFont(15, weight: .medium, relativeTo: .subheadline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Services

    @ViewBuilder
    private var servicesStep: some View {
        if vm.providers.isEmpty && !vm.isLoading {
            // TMDB had nothing for this region, or the request failed. Say
            // so plainly instead of showing an empty box the user will
            // think they broke.
            Text("We couldn't load the services for your region. You can set them later in Settings.")
                .appFont(15, relativeTo: .subheadline)
                .foregroundStyle(secondaryInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else {
            VStack(spacing: 20) {
                ProviderPickerGrid(providers: vm.providers,
                                   selectedIDs: vm.selectedProviderIDs,
                                   onToggle: vm.toggleProvider,
                                   revealed: revealed,
                                   reduceMotionOverride: reduceMotion,
                                   style: .cinema)

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
                .foregroundStyle(vm.selectedProviderIDs.isEmpty ? Color.white.opacity(0.7) : WatchnowBrand.gold)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)

            Text(vm.selectedProviderIDs.isEmpty
                 ? "We'll use this to tell you when something you saved lands somewhere you can actually watch it."
                 : "^[\(vm.selectedProviderIDs.count) service](inflect: true) selected. We'll tell you the moment a saved title lands on one.")
                .appFont(14, relativeTo: .subheadline)
                .foregroundStyle(secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background { glass(AppRadius.panel) }
        .animation(reduceMotion ? nil : AppMotion.springSoft, value: vm.selectedProviderIDs.isEmpty)
        .staggeredReveal(index: 9, isRevealed: revealed, reduceMotion: reduceMotion)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Poster steps

    private func posterStep(_ candidates: [Result],
                            isPicked: @escaping (Int?) -> Bool,
                            toggle: @escaping (Int) -> Void) -> some View {
        // One shimmer scope around the whole grid rather than one per cell:
        // the sweep travels by environment, so thirty loading covers share a
        // single animation and stay in phase with each other. Step three's
        // covers are fresh recommendation URLs that nothing has cached yet,
        // and without this it opens on nine flat rectangles.
        InlineShimmerContainer {
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
        }
        // Three covers across is the whole point of the grid; past the
        // accessibility sizes the labels stop fitting beside them. Every
        // title here is reachable uncapped from its details screen later.
        .artworkTypeClamp()
    }

    // MARK: - Finish

    private var finishStep: some View {
        VStack(spacing: 24) {
            ZStack {
                PayoffBurst(isOn: revealed, reduceMotion: reduceMotion)
                    .frame(width: 96, height: 96)
                badge(size: 72, glyph: 32)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                Text(title)
                    .appFont(30, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .staggeredReveal(index: 2, isRevealed: revealed, reduceMotion: reduceMotion)

                Text(subtitle)
                    .appFont(15, relativeTo: .subheadline)
                    .foregroundStyle(secondaryInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .staggeredReveal(index: 4, isRevealed: revealed, reduceMotion: reduceMotion)
            }
            .background { titleHalo }
            .accessibilityElement(children: .combine)

            if !vm.savedResults.isEmpty {
                InlineShimmerContainer {
                    HStack(spacing: 12) {
                        ForEach(Array(vm.savedResults.enumerated()), id: \.element.id) { index, result in
                            posterThumb(result)
                                .dealtCard(index: index, isDealt: revealed, reduceMotion: reduceMotion)
                        }
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
                    .offset(y: revealed || reduceMotion ? 0 : 22)
                    .animation(reduceMotion
                               ? .easeOut(duration: AppMotion.standard)
                               : .spring(response: 0.5, dampingFraction: 0.82).delay(0.5),
                               value: revealed)
            }
        }
    }

    private func posterThumb(_ result: Result) -> some View {
        // The aspect ratio is carried by the shape underneath, never by the
        // image — see the note in `PickablePoster`.
        Rectangle()
            .fill(OnboardingSurface.glass)
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay {
                KFImage(result.getPosterURL(width: .poster))
                    .placeholder { loadingCover }
                    .loadImmediately()
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(AppRadius.shape(AppRadius.card))
            .overlay {
                AppRadius.shape(AppRadius.card)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
    }

    // MARK: - Footer

    private var primaryActionTitle: LocalizedStringKey {
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
                    .foregroundStyle(vm.canContinue ? WatchnowBrand.gold : tertiaryInk)
                    // Counts up digit by digit rather than swapping whole,
                    // which is the difference between a label that changed
                    // and a target getting closer.
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : AppMotion.springSnappy, value: progress)
                    .accessibilityLabel("\(progress) chosen")
            }

            primaryButton

            if vm.step != .finish && vm.step != .welcome {
                Button {
                    Task { await vm.advance(skipping: true) }
                } label: {
                    Text("Skip")
                        .appFont(16, weight: .medium, relativeTo: .body)
                        .foregroundStyle(tertiaryInk)
                        .frame(maxWidth: .infinity, minHeight: AppTouch.minTarget)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        // The footer is a sibling of the pushed step, not part of it, so it
        // changes shape underneath the push: Skip exists on the three
        // questions and on neither of the screens either side of them.
        // Unanimated, it appeared instantly and sat on top of the primary
        // button for the length of the transition — caught in a frame grab
        // as "Get started" and "Skip" overlapping.
        .animation(reduceMotion ? nil : AppMotion.springSoft, value: vm.step)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .padding(.top, 8)
        // No solid plate under the footer — the wall's own bottom scrim is
        // already doing that. This is only here to stop the last row of
        // posters meeting the button on a hard line.
        .background {
            LinearGradient(stops: [
                .init(color: .black.opacity(0),    location: 0.00),
                .init(color: .black.opacity(0.55), location: 0.35),
                .init(color: .black.opacity(0.80), location: 1.00),
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private var primaryButton: some View {
        let shape = AppRadius.shape(AppRadius.panel)

        return Button {
            if vm.step == .finish { onFinish() } else { Task { await vm.advance() } }
        } label: {
            HStack(spacing: 8) {
                Text(primaryActionTitle)
                    .appFont(17, weight: .semibold, relativeTo: .body)
                    // "Get started" → "Continue" → "Go to my watchlist" is
                    // three different strings in one button; without this it
                    // is a hard swap mid-push.
                    .contentTransition(.opacity)
                Image(systemName: vm.step == .finish ? "arrow.right.circle.fill" : "arrow.right")
                    .appFont(15, weight: .bold, relativeTo: .body)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(vm.canContinue ? Color.white : Color.white.opacity(0.45))
            .frame(maxWidth: .infinity, minHeight: AppTouch.minTarget + 8)
            .background {
                ZStack {
                    shape.fill(vm.canContinue
                               ? AnyShapeStyle(LinearGradient(colors: [Color.accentColor, WatchnowBrand.blue],
                                                              startPoint: .topLeading,
                                                              endPoint: .bottomTrailing))
                               : AnyShapeStyle(Color.white.opacity(0.09)))
                    shape.strokeBorder(Color.white.opacity(vm.canContinue ? 0.28 : 0.14), lineWidth: 1)
                }
            }
            .shine(isActive: vm.canContinue, reduceMotion: reduceMotion, shape: shape)
            .shadow(color: Color.accentColor.opacity(vm.canContinue ? 0.5 : 0), radius: 18, y: 8)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!vm.canContinue)
        // A small lift the moment the step is satisfied, so the button
        // announces itself rather than quietly changing colour.
        .scaleEffect(vm.canContinue && !reduceMotion ? 1.02 : 1)
        .animation(reduceMotion ? nil : AppMotion.springBouncy, value: vm.canContinue)
        .sensoryFeedback(.impact(weight: .light), trigger: vm.canContinue) { _, now in now }
    }
}

// MARK: - Loading cover

/// The slot a cover occupies while its artwork is in flight.
///
/// `ShimmerBox` alone is `systemGray5`, which in the flow's forced-dark
/// subtree is dark enough to read as a hole punched in the grid rather than
/// as something arriving. The tint lifts it just clear of the scrimmed wall
/// behind it; the sweep — shared from the one `InlineShimmerContainer`
/// around the grid — is what says "loading".
private var loadingCover: some View {
    ShimmerBox(cornerRadius: AppRadius.card)
        .overlay {
            AppRadius.shape(AppRadius.card)
                .fill(Color.white.opacity(0.06))
        }
}

// MARK: - RecedingHeader

/// Fades and shrinks a header as it leaves the top of its scroll view.
///
/// `scrollTransition` and nothing else on purpose: it runs during drawing
/// and never writes state, so scrolling the grid underneath costs no view
/// updates. Deriving the same look from an `onScrollGeometryChange` handler
/// writing `@State` would re-render the whole step — thirty poster cells
/// included — sixty times a second. Same lesson as `WatchlistView`.
private struct RecedingHeader: ViewModifier {

    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .scrollTransition(topLeading: .interactive,
                                  bottomTrailing: .identity,
                                  axis: .vertical) { view, phase in
                    view
                        .opacity(1 + phase.value * 1.4)
                        .scaleEffect(1 + phase.value * 0.1, anchor: .top)
                        .offset(y: phase.value * -14)
                }
        }
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
                        .fill(OnboardingSurface.glass)
                        .aspectRatio(2 / 3, contentMode: .fit)
                        .overlay {
                            // `.poster`, not the default `original`: the
                            // cell is 120pt wide and the master is 2000px.
                            // Deliberately no `downsampling` processor — at
                            // this width there is nothing to downsample, and
                            // a processor would give the cell a different
                            // cache key from the prefetch that warmed it.
                            // `.loadImmediately()` is load-bearing, not an
                            // optimisation. A plain `KFImage` starts its
                            // download from `onAppear`, and inside this
                            // grid that never fires: the cells are built
                            // inside a `.transition`, in a `ZStack` that is
                            // remounted by `.id(vm.step)`, at `opacity(0)`
                            // until the cascade arms them. Step two looked
                            // fine only because the backdrop had already
                            // pulled those exact URLs into cache, so they
                            // rendered synchronously — step three, whose
                            // covers are always fresh, sat on grey
                            // placeholders forever. Starting the load at
                            // init sidesteps the whole question.
                            KFImage(result.getPosterURL(width: .poster))
                                .placeholder { loadingCover }
                                .loadImmediately()
                                .resizable()
                                .scaledToFill()
                        }
                        .clipShape(AppRadius.shape(AppRadius.card))
                        .overlay {
                            AppRadius.shape(AppRadius.card)
                                .strokeBorder(isPicked ? Color.accentColor : .white.opacity(0.16),
                                              lineWidth: isPicked ? 3 : 0.5)
                        }
                        .overlay {
                            if isPicked {
                                AppRadius.shape(AppRadius.card)
                                    .fill(Color.accentColor.opacity(0.24))
                            }
                        }
                        // Unpicked covers sit back a little and desaturate,
                        // so a grid of thirty reads as a field the picks
                        // rise out of rather than thirty equal shouts.
                        .saturation(isPicked ? 1 : 0.86)
                        .shadow(color: Color.accentColor.opacity(isPicked ? 0.55 : 0),
                                radius: 14, y: 6)

                    if isPicked {
                        Image(systemName: "checkmark.circle.fill")
                            .appFont(18, weight: .bold, relativeTo: .body)
                            .foregroundStyle(.white, Color.accentColor)
                            .padding(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(isPicked && !reduceMotion ? 1.05 : 1)

                Text(result.getResultTitle())
                    .appFont(12, weight: .medium, relativeTo: .caption)
                    .foregroundStyle(isPicked ? .white : Color.white.opacity(0.72))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : AppMotion.springBouncy, value: isPicked)
        .sensoryFeedback(.selection, trigger: isPicked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(result.getResultTitle())
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
    }
}
