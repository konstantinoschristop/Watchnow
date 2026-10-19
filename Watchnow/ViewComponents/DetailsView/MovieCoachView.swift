//
//  MovieCoachView.swift
//  Watchnow
//
//  The Movie Coach card on the details screen: a short, personal read on
//  whether this title is a good choice for *this* user right now.
//
//  Behaviour that matters:
//   - It never blocks the details screen. The card only appears once the
//     screen's own fetches have settled, and generation happens in a
//     `.task(id:)` that SwiftUI cancels automatically on disappear.
//   - Keyed on the context signature, so exactly one generation runs per
//     title (not one per fetch completing) and re-opening a title reuses the
//     cached answer instantly.
//   - If Foundation Models isn't available on this device, the whole section
//     renders as nothing — no placeholder, no apology.
//
//  Layout: the verdict on the left, a small fan of posters on the right —
//  this title in front, and behind it the saved titles it sits closest to
//  (`ContentDetailsViewModel.coachPosterPaths`), so the card shows what the
//  read is based on as well as saying it. The explanation runs full width
//  underneath, capped at four lines; a tap opens the rest.
//
//  Under it, a row of quick questions — "Why you'll like it", "Is it
//  scary?" — answered right there in the card, so asking Coach something
//  is one tap and no sheet. "Ask Coach" at the end of the row opens the
//  sheet with the rest.
//

import SwiftUI

struct MovieCoachView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    /// Nil until the details screen has finished loading the data Coach
    /// reads. Passing nil keeps the card in its loading state.
    let context: MovieCoachContext?
    /// This title's poster first, then up to two related saved titles.
    var posterPaths: [String] = []

    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var answer: MovieCoachAnswer?
    @State private var isMessageExpanded = false
    @State private var isGenerating = false
    @State private var didFail = false
    /// Non-nil while the Ask sheet is up. Carries the question to ask on
    /// arrival when the sheet was opened from "Why you'll like it".
    @State private var askRequest: AskRequest?

    /// The quick question whose answer is open in the card.
    @State private var openQuestion: String?
    /// Answers already given, by question — asked once per title.
    @State private var quickAnswers: [String: String] = [:]
    @State private var quickFailures: Set<String> = []
    @State private var askingQuestion: String?

    /// Waiting on the model (or on the screen's data, before that).
    private var isThinking: Bool {
        answer == nil && !didFail
    }

    private struct AskRequest: Identifiable {
        let id = UUID()
        var initialQuestion: String? = nil
    }

    var body: some View {
        // Hidden entirely on devices/OS versions without on-device models.
        if MovieCoachService.isReady {
            Group {
                if MovieCoachService.hasEnoughHistory {
                    card
                } else {
                    // Not enough taste history yet — say so plainly
                    // rather than offering a guess.
                    warmUpHint
                }
            }
            .padding(.horizontal)
            .task(id: context?.signature) {
                await load()
            }
        }
    }

    /// Small attribution line inside the card. The section header used to sit
    /// above it saying "Movie Coach" — which was both wrong on a series and a
    /// waste of the most valuable line on the card. The verdict gets that
    /// space now; the feature name shrinks to an eyebrow.
    private var eyebrow: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkles")
                .appFont(10, weight: .bold, relativeTo: .caption2)
                // Shimmers while Coach is thinking, hops once when it has
                // an answer. Both stop by themselves.
                .symbolEffect(.variableColor.iterative.reversing,
                              options: .speed(1.4),
                              isActive: isThinking && !reduceMotion)
                .symbolEffect(.bounce, value: answer != nil)
            Text("COACH")
                .appFont(11, weight: .heavy, relativeTo: .caption2, design: .rounded)
                .tracking(1.1)
        }
        .foregroundStyle(Color.accentColor)
    }

    // MARK: - Warm-up hint

    /// Shown until Coach knows `minimumWatchlistSize` titles. Frames the
    /// threshold as progress rather than a lockout.
    private var warmUpHint: some View {
        let known = MovieCoachService.knownTitleCount
        let target = MovieCoachService.minimumWatchlistSize
        let remaining = max(0, target - known)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                eyebrow
                Spacer(minLength: 0)
                Text("🎬").appFont(26, relativeTo: .title).accessibilityHidden(true)
            }

            Text("Getting to know your taste")
                .appFont(20, weight: .heavy, relativeTo: .title3)
                .foregroundStyle(.primary)

            Text("Save or like \(remaining) more titles and Movie Coach will start telling you whether something's a good fit for you.", comment: "Movie Coach progress card. The number is how many more titles the user needs.")
                .appFont(14, relativeTo: .subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ProgressView(value: Double(known), total: Double(target))
                    .tint(Color.accentColor)
                Text("\(known) of \(target)")
                    .appFont(12, weight: .semibold, relativeTo: .caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .modifier(CoachCardSurface(prominence: .quiet))
    }

    // MARK: - Card

    @ViewBuilder
    private var card: some View {
        let prominence = answer?.verdict.prominence ?? .quiet

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 2) {
                        eyebrow
                        if answer != nil { refreshButton }
                    }
                    .frame(minHeight: 18, alignment: .leading)

                    if let answer {
                        verdictBlock(answer)
                            .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
                    } else if didFail {
                        failureRow
                    } else {
                        verdictSkeleton
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // The text needs the whole width at accessibility sizes.
                if !typeSize.isAccessibilitySize {
                    if !posterPaths.isEmpty {
                        PosterFan(paths: posterPaths)
                    } else if let answer {
                        Text(answer.verdict.emoji)
                            .appFont(30, relativeTo: .title)
                            .accessibilityHidden(true)
                    }
                }
            }

            if let answer {
                message(answer)
                    .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
                quickQuestionRow(for: answer)
                    .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 8)))
                if let openQuestion {
                    quickAnswer(for: openQuestion)
                        .transition(reduceMotion ? AnyTransition.opacity
                                                 : .opacity.combined(with: .offset(y: -6)))
                }
            } else if !didFail {
                messageSkeleton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .modifier(CoachCardSurface(prominence: prominence, isThinking: isThinking))
        .animation(reduceMotion ? .easeInOut(duration: AppMotion.standard) : .spring(response: 0.5, dampingFraction: 0.85), value: answer)
        .animation(reduceMotion ? nil : .easeInOut(duration: AppMotion.standard), value: didFail)
        .animation(reduceMotion ? .easeInOut(duration: AppMotion.standard) : .spring(response: 0.45, dampingFraction: 0.85),
                   value: openQuestion)
        .animation(reduceMotion ? .easeInOut(duration: AppMotion.standard) : .spring(response: 0.45, dampingFraction: 0.85),
                   value: quickAnswers)
        // A different title (or a fresh read) makes old answers stale.
        .onChange(of: context?.signature) { _, _ in resetQuickQuestions() }
        .coversDetailsPage(askRequest != nil)
        .sheet(item: $askRequest) { request in
            if let context {
                MovieCoachAskSheet(context: context, initialQuestion: request.initialQuestion)
            }
        }
    }

    /// The whole point of the feature, sized like it.
    private func verdictBlock(_ answer: MovieCoachAnswer) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(answer.verdict.headline)
                .appFont(26, weight: .heavy, relativeTo: .title)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(answer.verdict.subhead)
                .appFont(15, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(.primary.opacity(0.85))
        }
    }

    /// Four lines, then a tap for the rest. The model doesn't always keep
    /// to the "one to three short sentences" it is asked for, and at full
    /// length the explanation pushed where-to-watch off the first screen.
    /// VoiceOver reads the whole text either way.
    private func message(_ answer: MovieCoachAnswer) -> some View {
        Text(answer.message)
            .appFont(15, relativeTo: .subheadline)
            .foregroundStyle(.secondary)
            .lineSpacing(1.5)
            .lineLimit(isMessageExpanded ? nil : 4)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: AppMotion.standard)) {
                    isMessageExpanded.toggle()
                }
            }
    }

    // MARK: - Quick questions

    private struct QuickQuestion: Identifiable {
        let label: String
        let question: String
        var symbol: String? = nil
        var id: String { question }
    }

    /// Up to three questions worth asking about *this* title: why you'll
    /// like it (only when Coach thinks you will), then the most specific
    /// of the suggestions — scary, slow, a big commitment. "Is this a good
    /// choice tonight?" is skipped: the verdict above is its answer.
    private func quickQuestions(for answer: MovieCoachAnswer) -> [QuickQuestion] {
        guard let context else { return [] }
        var questions: [QuickQuestion] = []
        if answer.verdict == .greatPick || answer.verdict == .goodPick {
            questions.append(QuickQuestion(
                label: String(localized: "Why you'll like it", comment: "Movie Coach button: asks Coach why this title suits the user"),
                question: MovieCoachService.whyWatchQuestion,
                symbol: "sparkles"))
        }
        let skip: Set<String> = [MovieCoachService.tonightQuestion, MovieCoachService.whyWatchQuestion]
        for question in MovieCoachService.suggestedQuestions(for: context) where !skip.contains(question) {
            questions.append(QuickQuestion(label: question, question: question))
        }
        return Array(questions.prefix(3))
    }

    private func quickQuestionRow(for answer: MovieCoachAnswer) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickQuestions(for: answer)) { quick in
                    Button {
                        ask(quick.question)
                    } label: {
                        chipLabel(quick.label, symbol: quick.symbol,
                                  selected: openQuestion == quick.question)
                    }
                    .buttonStyle(CarouselPressStyle())
                }
                Button {
                    askRequest = AskRequest()
                } label: {
                    chipLabel(String(localized: "Ask Coach"),
                              symbol: "bubble.left.and.text.bubble.right",
                              selected: false, prominent: true)
                }
                .buttonStyle(CarouselPressStyle())
            }
            .padding(.horizontal, 18)
        }
        // Edge to edge of the card, so the row scrolls under its padding
        // instead of stopping short of it.
        .padding(.horizontal, -18)
        .disabled(context == nil)
    }

    private func chipLabel(_ text: String, symbol: String?, selected: Bool, prominent: Bool = false) -> some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .imageScale(.small)
            }
            Text(text)
                .lineLimit(1)
        }
        .appFont(14, weight: .semibold, relativeTo: .subheadline)
        .foregroundStyle(selected ? Color.white : (prominent ? Color.accentColor : Color.primary))
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background {
            Capsule().fill(selected ? Color.accentColor
                                    : (prominent ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.06)))
        }
        .contentShape(Capsule())
    }

    @ViewBuilder
    private func quickAnswer(for question: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .appFont(14, weight: .bold, relativeTo: .subheadline)
                .foregroundStyle(Color.accentColor)

            if let text = quickAnswers[question] {
                Text(text)
                    .appFont(15, relativeTo: .subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
            } else if quickFailures.contains(question) {
                HStack(spacing: 10) {
                    Text("Couldn't answer that one.")
                        .appFont(14, relativeTo: .subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Retry") { ask(question, forceOpen: true) }
                        .appFont(13, weight: .semibold, relativeTo: .footnote)
                        .foregroundStyle(Color.accentColor)
                        .buttonStyle(.plain)
                }
            } else {
                Text("Thinking that through for you right now.")
                    .appFont(15, relativeTo: .subheadline)
                    .redacted(reason: .placeholder)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.accentColor.opacity(0.08), in: AppRadius.shape(AppRadius.panel))
    }

    /// Opens the answer for `question` in the card, asking Coach the first
    /// time. Tapping the open question again folds it away.
    private func ask(_ question: String, forceOpen: Bool = false) {
        guard let context else { return }
        if openQuestion == question, !forceOpen {
            openQuestion = nil
            return
        }
        openQuestion = question
        guard quickAnswers[question] == nil, askingQuestion != question else { return }
        quickFailures.remove(question)
        askingQuestion = question
        Task {
            do {
                let text = try await MovieCoachService.answer(question: question, context: context)
                quickAnswers[question] = text
            } catch {
                quickFailures.insert(question)
            }
            if askingQuestion == question { askingQuestion = nil }
        }
    }

    private func resetQuickQuestions() {
        openQuestion = nil
        quickAnswers = [:]
        quickFailures = []
        askingQuestion = nil
    }

    private var refreshButton: some View {
        Button {
            Task { await regenerate() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .appFont(11, weight: .bold, relativeTo: .caption2)
                .foregroundStyle(Color.secondary)
                .frame(width: AppTouch.minTarget, height: AppTouch.minTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // A full 44pt target without making the eyebrow line 44pt tall.
        .padding(.vertical, -13)
        .accessibilityLabel("Ask Coach again")
    }

    private var failureRow: some View {
        HStack(spacing: 10) {
            Text("Couldn't get a read on this one.")
                .appFont(14, relativeTo: .subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("Retry") { Task { await regenerate() } }
                .appFont(13, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(Color.accentColor)
                .buttonStyle(.plain)
        }
    }

    /// Redacted stand-ins in the real card's shape, so nothing jumps when
    /// the answer lands.
    private var verdictSkeleton: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Great pick")
                .appFont(26, weight: .heavy, relativeTo: .title)
            Text("This one's for you")
                .appFont(15, weight: .semibold, relativeTo: .subheadline)
        }
        .redacted(reason: .placeholder)
    }

    private var messageSkeleton: some View {
        Text("Checking whether this is a good match for you right now and how it fits your evening.")
            .appFont(15, relativeTo: .subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .redacted(reason: .placeholder)
    }

    // MARK: - Generation

    private func load() async {
        guard let context else { return }

        // Refresh TMDB's "also liked" graph in the background — weekly at
        // most, and entirely optional to the verdict.
        Task { await TasteProfile.rebuildGraphIfNeeded(using: ServiceInvocation()) }

        // Nothing to generate while the warm-up hint is showing.
        guard MovieCoachService.isReady, MovieCoachService.hasEnoughHistory else { return }

        let key = MovieCoachCache.key(mediaType: context.kind, id: String(context.tmdbID))
        if let cached = MovieCoachCache.read(key: key, signature: context.signature) {
            answer = cached
            didFail = false
            return
        }
        await generate(context: context, key: key)
    }

    private func regenerate() async {
        guard let context else { return }
        let key = MovieCoachCache.key(mediaType: context.kind, id: String(context.tmdbID))
        MovieCoachCache.invalidate(key: key)
        answer = nil
        resetQuickQuestions()
        await generate(context: context, key: key)
    }

    private func generate(context: MovieCoachContext, key: String) async {
        guard !isGenerating else { return }
        isGenerating = true
        didFail = false
        defer { isGenerating = false }

        do {
            let generated = try await MovieCoachService.verdict(for: context)
            guard !Task.isCancelled else { return }
            answer = generated
            MovieCoachCache.write(generated, key: key, signature: context.signature)
        } catch {
            #if DEBUG
            print("[MovieCoach] generation failed: \(error)")
            #endif
            guard !Task.isCancelled else { return }
            didFail = true
        }
    }
}

// MARK: - Poster fan

/// This title's poster, with up to two related saved titles fanned out
/// behind it. Decorative — the verdict says the same thing in words — so
/// it can afford to be a little playful: the cards deal out from a stack
/// when the card appears, and a tap shuffles them.
private struct PosterFan: View {

    let paths: [String]

    /// Which poster sits in which slot; rotated by a tap.
    @State private var order: [Int] = []
    @State private var dealt = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let front = CGSize(width: 66, height: 99)
    private let back = CGSize(width: 54, height: 81)

    var body: some View {
        // The related posters usually arrive after the fan first appears
        // (they need the similar titles), so an order remembered from then
        // can be short.
        let slots = order.count == paths.count ? order : Array(paths.indices)

        ZStack {
            // Back slots first so the front one draws on top.
            ForEach(Array(slots.enumerated().reversed()), id: \.element) { slot, index in
                poster(paths[index], size: slot == 0 ? front : back)
                    .rotationEffect(.degrees(dealt ? rotation(for: slot) : 0))
                    .offset(x: dealt ? xOffset(for: slot) : 0, y: slot == 0 ? 0 : 8)
                    .zIndex(Double(paths.count - slot))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.75), value: paths)
        .frame(width: paths.count > 1 ? 132 : front.width, height: 108)
        .contentShape(Rectangle())
        .onTapGesture { shuffle() }
        .sensoryFeedback(.selection, trigger: order)
        .accessibilityHidden(true)
        .onChange(of: paths) { _, newPaths in
            order = Array(newPaths.indices)
        }
        .onAppear {
            if order.count != paths.count { order = Array(paths.indices) }
            guard !dealt else { return }
            if reduceMotion {
                dealt = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15)) { dealt = true }
            }
        }
    }

    private func rotation(for slot: Int) -> Double {
        switch slot {
        case 1: return -10
        case 2: return 10
        default: return 0
        }
    }

    private func xOffset(for slot: Int) -> CGFloat {
        switch slot {
        case 1: return -32
        case 2: return 32
        default: return 0
        }
    }

    private func shuffle() {
        guard paths.count > 1 else { return }
        var next = order.count == paths.count ? order : Array(paths.indices)
        next.append(next.removeFirst())
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.72)) {
            order = next
        }
    }

    private func poster(_ path: String, size: CGSize) -> some View {
        RemoteImage(url: URL(string: API.Common.imageUrl(imageId: path, width: .poster)))
            .frame(width: size.width, height: size.height)
            .clipShape(AppRadius.shape(AppRadius.small))
            .overlay {
                AppRadius.shape(AppRadius.small)
                    .strokeBorder(.white.opacity(0.7), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}

// MARK: - Card surface

/// Glass surface for the Coach card, plus the rotating spectrum edge that
/// marks it as the intelligence feature.
///
/// Follows the same iOS 26 / fallback split as `ActionPillBackground`:
/// liquid glass where it exists, material + fill below. Confidence is carried
/// by how strongly the glass is tinted, so the palette stays accent-only —
/// the moving border is the one deliberate exception, and it earns it by
/// saying "a model wrote this" rather than by decorating.
private struct CoachCardSurface: ViewModifier {

    let prominence: MovieCoachVerdict.Prominence
    /// The rim light travels while Coach is writing, and rests once it has.
    var isThinking: Bool = false
    private let radius: CGFloat = AppRadius.surface

    func body(content: Content) -> some View {
        surface(content)
            // Behind the glass, not on top of it. The material samples its
            // backdrop, so the glow gets refracted and diffused through the
            // card instead of sitting on the surface as a drawn-on ring —
            // which is what makes it read as lit from within. Boosted a
            // little because the glass eats some of the intensity.
            // Big, soft light source *behind* the glass — this is what the
            // material picks up and diffuses through the card.
            .background {
                IntelligenceBorder(cornerRadius: radius,
                                   opacity: glowOpacity,
                                   thickness: glowThickness,
                                   blurRadius: 11,
                                   isLive: isThinking)
            }
            // A hairline of the same gradient *on top*, so the card still has
            // a defined edge. Diffused light alone reads as a smudge; this
            // gives it a crisp outline to sit inside.
            .overlay {
                IntelligenceBorder(cornerRadius: radius,
                                   opacity: 0.5,
                                   thickness: 1.2,
                                   blurRadius: 0.4,
                                   masked: false,
                                   isLive: isThinking)
            }
    }

    /// The same solid card as the other details sections (see
    /// `DetailsCardSurface`), with a faint wash in the top corner so the one
    /// card a model wrote reads as related to the glow around it.
    /// The glow lives behind and reads as a rim rather than light shining
    /// through the panel.
    private func surface(_ content: Content) -> some View {
        content.background {
            ZStack {
                // The shadow on the card's shape alone: on the whole card
                // it would be redrawn whenever anything inside changed —
                // every frame of the rim light's travel.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                // A soft light behind the poster fan, in the rim's own
                // colours, so the glow seems to come from inside the card.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(RadialGradient(colors: [Color(red: 1.0, green: 0.42, blue: 0.72).opacity(0.10), .clear],
                                         center: .topTrailing,
                                         startRadius: 0,
                                         endRadius: 220))
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(RadialGradient(colors: [Color.accentColor.opacity(0.08), .clear],
                                         center: UnitPoint(x: 0.7, y: 0.0),
                                         startRadius: 0,
                                         endRadius: 300))
            }
        }
    }

    /// Confidence now rides on how brightly the card is lit from behind,
    /// rather than on how strongly its surface is tinted.
    private var glowOpacity: Double {
        switch prominence {
        case .loud:   return 0.50
        case .tinted: return 0.40
        case .quiet:  return 0.30
        }
    }

    private var glowThickness: CGFloat {
        switch prominence {
        case .loud:   return 8
        case .tinted: return 6
        case .quiet:  return 5
        }
    }
}

/// The Siri / Apple-Intelligence edge glow.
///
/// The character of that effect isn't a spinning rainbow — it's a soft bloom
/// hugging the edge whose *thickness varies organically* around the
/// perimeter: fat magenta in one corner, a thin blue stretch opposite, warm
/// amber pooling somewhere else. It drifts slowly rather than racing.
///
/// How that's built here:
///  - The gradient's stops vary in **opacity as well as hue**. Blurred, a
///    full-opacity arc blooms wide while a 30%-opacity one stays a whisper —
///    that difference is what reads as uneven thickness. A uniform
///    `lineWidth` alone can never produce it.
///  - The gradient is applied *as the stroke of the card's own shape*, and
///    rotated via the gradient's `angle:` rather than a `rotationEffect`.
///    An earlier attempt rasterised a blurred gradient with `.drawingGroup()`
///    and rotated that layer — the cached layer's bounds stopped matching the
///    card, so the mask clipped the wrong rectangle and the "glow" came out
///    as two neon bars above and below the card. Stroking the real shape
///    can't drift out of alignment.
private struct IntelligenceBorder: View {

    let cornerRadius: CGFloat
    var opacity: Double = 1.0
    /// Geometric stroke width; the blur and the gradient's opacity swings do
    /// the rest of the sculpting.
    var thickness: CGFloat = 10
    /// Blur applied to the glow. Generous behind the glass — the material
    /// diffuses whatever sits under it, so a thin source simply disappears —
    /// and near-zero for the crisp edge drawn on top.
    var blurRadius: CGFloat = 9
    /// Confine the glow to a band around the edge. Off for the thin edge
    /// pass, which is already only as wide as its own stroke.
    var masked: Bool = true
    /// Travelling. Off, it rests where it is — a light that kept lapping a
    /// card the reader has moved on to would only cost frames.
    var isLive: Bool = true

    /// One slow lap. Siri's glow drifts — it doesn't chase.
    private let lapDuration: Double = 16

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let magenta = Color(red: 1.00, green: 0.24, blue: 0.62)
    private static let purple  = Color(red: 0.66, green: 0.33, blue: 1.00)
    private static let blue    = Color(red: 0.28, green: 0.55, blue: 1.00)
    private static let amber   = Color(red: 1.00, green: 0.62, blue: 0.25)

    /// Uneven on purpose — the opacity swings are what sculpt the thickness.
    private var stops: [Gradient.Stop] {
        [
            .init(color: Self.magenta,               location: 0.00),
            .init(color: Self.magenta.opacity(0.95), location: 0.10),
            .init(color: Self.purple.opacity(0.55),  location: 0.22),
            .init(color: Self.blue.opacity(0.30),    location: 0.34),
            .init(color: Self.blue.opacity(0.85),    location: 0.46),
            .init(color: Self.purple.opacity(0.40),  location: 0.58),
            .init(color: Self.amber.opacity(1.00),   location: 0.70),
            .init(color: Self.amber.opacity(0.45),   location: 0.80),
            .init(color: Self.magenta.opacity(0.75), location: 0.90),
            .init(color: Self.magenta,               location: 1.00)
        ]
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        // The gradient is built **without** an angle and rotated as a view.
        //
        // Feeding `phase` into `AngularGradient(angle:)` meant the gradient —
        // and every blur applied over it — was re-rendered on every frame.
        // Blur is an offscreen pass, so at 60fps alongside a scrolling
        // ScrollView that was enough to visibly stutter the whole details
        // screen. Here the blurred gradient is rasterised once by
        // `drawingGroup()` and the animation only spins that cached texture,
        // which is a GPU transform and effectively free.
        //
        // The angle comes from the clock, so pausing the timeline leaves the
        // light exactly where it was — no jump when Coach finishes.
        TimelineView(.animation(paused: !isLive || reduceMotion)) { timeline in
        GeometryReader { geo in
            let side = max(geo.size.width, geo.size.height) * 1.6
            AngularGradient(gradient: Gradient(stops: stops), center: .center)
                .frame(width: side, height: side)
                .blur(radius: blurRadius)
                .drawingGroup()
                .rotationEffect(.degrees(angle(at: timeline.date)))
                // Collapse back to the card's box so the mask below lines up
                // with the card and not with the rotated layer's bounds —
                // getting this wrong previously produced neon bars floating
                // above and below the card.
                //
                // Deliberately *not* `.clipped()`: that clips to a rectangle,
                // so anywhere the blurred mask reached past a rounded corner
                // it exposed the square bounding box and the glow came out
                // with visible straight corners. The mask below is already a
                // rounded stroke, so it's the only clip needed.
                .frame(width: geo.size.width, height: geo.size.height)
        }
        }
        .mask(
            masked
            // A narrow band keeps the light on the rim. Wider than ~2× and it
            // reaches the middle of the card, leaving the body copy sitting
            // on a magenta wash.
            ? AnyView(shape.strokeBorder(lineWidth: thickness * 2).blur(radius: blurRadius))
            // Crisp hairline pass — its own stroke is already the full extent.
            : AnyView(shape.strokeBorder(lineWidth: thickness))
        )
        .opacity(opacity)
        .allowsHitTesting(false)
    }

    /// Where the light is on its lap at `date`. Reduce Motion parks it —
    /// the border stays, it just doesn't travel.
    private func angle(at date: Date) -> Double {
        let lap = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: lapDuration)
        return lap / lapDuration * 360
    }
}
