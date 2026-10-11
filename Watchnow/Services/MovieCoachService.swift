//
//  MovieCoachService.swift
//  Watchnow
//
//  Movie Coach — an on-device second opinion on the title you're looking at.
//
//  Runs entirely through Apple's Foundation Models framework (iOS 26+), so
//  the user's watchlist, folders and service preferences never leave the
//  device. There is no backend and no remote AI call.
//
//  Two hard rules shape this file:
//
//   1. The model synthesises, it never recalls. Every fact it is allowed to
//      mention is assembled deterministically in `MovieCoachContext`; the
//      instructions forbid inventing anything that isn't in that block.
//   2. Everything is gated. The app's deployment target is iOS 18, and even
//      on iOS 26 the model can be unavailable (ineligible device, Apple
//      Intelligence off, model still downloading). Callers get a plain
//      `Availability` value and simply hide the feature when it isn't ready.
//
//  Prompt text is versioned via `promptVersion` — bump it whenever the
//  instructions change so previously cached answers are discarded.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Plain result types (available on every OS version)

/// How strongly Coach is recommending the title *right now*. Deliberately
/// small — the UI owns presentation, the model only picks a bucket.
enum MovieCoachVerdict: String, Codable, Sendable {
    case greatPick
    case goodPick
    case maybeLater
    case notIdealRightNow

    /// Short headline shown above the explanation. Written as a decision,
    /// not a hedge — this is the line the whole feature exists to deliver.
    var headline: String {
        switch self {
        case .greatPick:        return String(localized: "Great pick", comment: "Movie Coach verdict headline")
        case .goodPick:         return String(localized: "Worth a watch", comment: "Movie Coach verdict headline")
        case .maybeLater:       return String(localized: "Save this for later", comment: "Movie Coach verdict headline")
        case .notIdealRightNow: return String(localized: "Probably not tonight", comment: "Movie Coach verdict headline")
        }
    }

    /// `headline` as the prompt names it. The prompt is written in English
    /// whatever the app's language, and so is this.
    var promptName: String {
        switch self {
        case .greatPick:        return "Great pick"
        case .goodPick:         return "Worth a watch"
        case .maybeLater:       return "Save this for later"
        case .notIdealRightNow: return "Probably not tonight"
        }
    }

    /// One line of context under the headline, so the verdict reads as a
    /// judgement rather than a label.
    var subhead: String {
        switch self {
        case .greatPick:        return String(localized: "This one's for you", comment: "Movie Coach verdict subheading")
        case .goodPick:         return String(localized: "A solid option tonight", comment: "Movie Coach verdict subheading")
        case .maybeLater:       return String(localized: "Right film, wrong moment", comment: "Movie Coach verdict subheading")
        case .notIdealRightNow: return String(localized: "There are better calls tonight", comment: "Movie Coach verdict subheading")
        }
    }

    var icon: String {
        switch self {
        case .greatPick:        return "sparkles"
        case .goodPick:         return "hand.thumbsup.fill"
        case .maybeLater:       return "clock.fill"
        case .notIdealRightNow: return "questionmark.circle.fill"
        }
    }

    /// Carries the verdict at a glance, before a word is read. Warmer than an
    /// SF Symbol and keeps the card from feeling like a system alert.
    var emoji: String {
        switch self {
        case .greatPick:        return "🍿"
        case .goodPick:         return "👍"
        case .maybeLater:       return "⏳"
        case .notIdealRightNow: return "🤔"
        }
    }

    /// How loudly the card should present itself. Confidence is expressed as
    /// accent *intensity* rather than a different hue, so a strong yes leaps
    /// off the page while the app keeps a single-colour palette.
    enum Prominence { case loud, tinted, quiet }

    var prominence: Prominence {
        switch self {
        case .greatPick:                    return .loud
        case .goodPick:                     return .tinted
        case .maybeLater, .notIdealRightNow: return .quiet
        }
    }
}

/// A finished Coach answer, safe to cache and render on any OS version.
struct MovieCoachAnswer: Codable, Sendable, Equatable {
    let verdict: MovieCoachVerdict
    let message: String
}

// MARK: - Generable mirror (iOS 26+)

#if canImport(FoundationModels)

/// Structured output for the card. Only the prose is generated — the verdict
/// itself is decided in `MovieCoachContext.verdictCall`, because when the
/// model picked the bucket it labelled almost everything "worth a watch".
@available(iOS 26.0, *)
@Generable
struct MovieCoachResponse {

    @Guide(description: "One to three short sentences explaining the verdict in a warm, direct voice with real personality — specific and vivid, like a friend who knows exactly what you love. Never generic, never templated. No spoilers, no synopsis retelling, no mention of data or preferences as a concept.")
    let message: String
}

#endif

// MARK: - Service

@MainActor
enum MovieCoachService {

    /// Bump when the instructions or context format change — invalidates
    /// every cached answer produced by an older prompt.
    /// v2 — user context switched to positive-only statements after the model
    /// read "Saved to watchlist: no" and told users they'd saved a title they
    /// hadn't.
    /// v3 — verdict moved out of the model (it answered "worth a watch" for
    /// nearly everything) and is now decided in `MovieCoachContext`.
    /// v4 — added disqualifiers (shorts, uncredible ratings, taste/language
    /// mismatch) and stopped demoting already-saved titles for being long.
    /// v5 — TMDB keywords joined the context: the title's themes plus the
    /// themes recurring across the user's watchlist, so answers can connect
    /// the two ("you keep saving time-travel mysteries — this is one").
    /// v6 — every card was opening with the same "you clearly go…" pattern
    /// (the model parroted an example phrase from the v5 instructions).
    /// Dropped the quotable example, banned stock openers, added a rotating
    /// opening angle per generation, and raised temperature.
    /// v7 — answers in the app's language when the model supports it.
    /// Bumping discards answers generated under any older prompt.
    static let promptVersion = 7

    /// Coach only speaks up once it has enough saved titles to actually know
    /// the user's taste. Below this it would be guessing dressed up as advice,
    /// so the card shows a short "save a few more" hint instead.
    static let minimumWatchlistSize = 5

    static var savedTitleCount: Int { WatchlistManager.watchlist.count }

    /// Titles Coach can reason about: everything saved, plus everything the
    /// user has explicitly said they love.
    ///
    /// Counting saves alone would have kept Coach silent for exactly the
    /// user who has just told it the most. Onboarding asks for five loves
    /// and three saves, and a love is the stronger signal of the two — a
    /// deliberate "this is my kind of thing" against a save's "maybe
    /// later". Ignoring five of them because they weren't bookmarks would
    /// make the bar arithmetic rather than meaningful.
    static var knownTitleCount: Int {
        Set(WatchlistManager.watchlist.compactMap(\.id))
            .union(TasteProfile.likedIDs)
            .count
    }

    static var hasEnoughHistory: Bool { knownTitleCount >= minimumWatchlistSize }

    /// Why Coach can or can't run. The UI hides itself for anything but
    /// `.ready`, so an unsupported device simply never sees the feature.
    enum Availability: Equatable {
        case ready
        /// Running below iOS 26, or built without the framework.
        case unsupportedOS
        /// iOS 26+, but the system model isn't usable on this device.
        case modelUnavailable
    }

    static var availability: Availability {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return .unsupportedOS }
        switch SystemLanguageModel.default.availability {
        case .available:
            // Coach reads the title's facts in the TMDB language and words its
            // card in the app's; a model that can't handle either would fail
            // on every card rather than answer, so it stays hidden instead.
            let model = SystemLanguageModel.default
            let appLanguage = Bundle.main.preferredLocalizations.first ?? "en"
            guard model.supportsLocale(Locale(identifier: appLanguage)),
                  model.supportsLocale(Locale(identifier: API.language))
            else { return .modelUnavailable }
            return .ready
        case .unavailable:    return .modelUnavailable
        @unknown default:     return .modelUnavailable
        }
        #else
        return .unsupportedOS
        #endif
    }

    static var isReady: Bool { availability == .ready }

    enum CoachError: Error { case unavailable }

    // MARK: Instructions

    /// The system prompt. Centralised here (never inline in a View) and
    /// covered by `promptVersion`.
    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static var instructions: String {
        // Said even for English: the facts may arrive in another language
        // (TMDB follows the device's), and the answer must still match the
        // app's own.
        baseInstructions + "\n- Write every answer in \(responseLanguage ?? "English"), naturally, as a native speaker would."
    }

    /// The language Coach answers in, named in English for the prompt: the
    /// language the app's own text is in, so the card reads as one piece.
    /// Nil for English. (A language the model doesn't support never gets
    /// this far: `availability` hides Coach for it.)
    @available(iOS 26.0, *)
    private static var responseLanguage: String? {
        guard let code = Bundle.main.preferredLocalizations.first, !code.hasPrefix("en"),
              SystemLanguageModel.default.supportsLocale(Locale(identifier: code))
        else { return nil }
        return Locale(identifier: "en").localizedString(forIdentifier: code)
    }
    #endif

    /// Room for one to three sentences. More than English needs, because the
    /// same sentences in German, French or Spanish run to more tokens and a
    /// guided answer cut off at the cap fails outright.
    private static let responseTokenLimit = 300

    private static let baseInstructions = """
    You are Movie Coach inside the WatchNow app. You help the user decide \
    whether the movie or series they are looking at is a good choice for them.

    Use ONLY the facts in the CONTEXT block. Never invent or guess actors, \
    ratings, plot points, streaming availability, release dates, awards, \
    reviews, or anything about the user. If a fact is not in the context, do \
    not mention it.

    The USER_CONTEXT block lists ONLY things that are true. If a statement \
    does not appear there, it is false. Never say the user has saved, \
    bookmarked, shortlisted, or set a reminder for this title unless that \
    exact line is present. When USER_CONTEXT is empty, say nothing at all \
    about the user's history.

    Rules:
    - Do not spoil the story. Never reveal twists or the ending.
    - Do not retell the synopsis. Assume the user can already read it.
    - Be concise: one to three short sentences.
    - Be confident but never absolute. Prefer "you'll probably enjoy this" or \
    "this looks like a strong match" over "you will love this".
    - Use personal context only when it genuinely sharpens the answer. If the \
    context shows little personal signal, give a useful assessment of the \
    title itself and do not pretend it is personalised.
    - When the context says this title hits themes the user keeps saving, \
    that connection is the most useful thing you can say. Weave one or two \
    of those shared themes into a sentence — never recite them as a list, \
    and only ever connect themes the context itself pairs up.
    - Never open with a stock phrase. Openers like "you clearly", "you seem \
    to", "based on your", or restating the title's name read as canned — \
    find an angle that fits this specific title instead, and let each answer \
    sound different from the last.
    - Weigh practical fit: runtime, number of seasons, and whether it is \
    already out or still unreleased.
    - Never mention data, context, preferences-as-a-concept, algorithms, or \
    that you are an AI. Never say "based on your preferences" or "according \
    to the data". Just speak naturally, like a friend with good taste.
    """

    // MARK: Verdict

    /// One of these is appended to every verdict prompt so consecutive cards
    /// don't all open the same way. The verdict and the facts stay fixed —
    /// only the angle of attack rotates. Picked at random per generation, so
    /// "Ask again" genuinely re-rolls the voice too.
    private static let openingAngles = [
        "Open with the story's hook itself, then land the recommendation.",
        "Open by speaking to the user's taste directly — but never by narrating it back as data.",
        "Open with how this fits tonight practically, then why it suits them.",
        "Open with the single strongest fact in the context, stated plainly.",
        "Open mid-thought, like you're continuing a chat about what to watch tonight."
    ]

    /// Generate the card's verdict + explanation for a title.
    static func verdict(for context: MovieCoachContext) async throws -> MovieCoachAnswer {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *), isReady else { throw CoachError.unavailable }

        // The verdict is decided from the facts, not by the model.
        let call = context.verdictCall

        let session = LanguageModelSession(instructions: instructions)
        let prompt = """
        CONTEXT:
        \(context.promptText)

        \(context.hasMeaningfulPersonalSignal
            ? "There is real personal signal here — use it where it helps."
            : "There is little personal signal — assess the title on its own merits and do not imply personalisation.")

        The verdict has already been decided: "\(call.verdict.promptName)".
        The reason is: \(call.reason).

        Write one to three short sentences telling the user that, in your own \
        natural wording. Agree with the verdict — do not argue against it or \
        soften it into a different conclusion. Only mention facts from the \
        context. \(openingAngles.randomElement() ?? "")
        """

        // Temperature runs hotter than the ask-sheet's: the facts and the
        // verdict are pinned by the prompt, so the extra heat only buys
        // wording variety between cards — the thing that stops every answer
        // sounding like the same sentence with nouns swapped.
        let response = try await session.respond(
            to: prompt,
            generating: MovieCoachResponse.self,
            options: GenerationOptions(temperature: 0.8, maximumResponseTokens: responseTokenLimit)
        )
        let message = response.content.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return MovieCoachAnswer(verdict: call.verdict, message: message)
        #else
        throw CoachError.unavailable
        #endif
    }

    // MARK: Ask

    /// Answer one of the suggested follow-up questions. Returns free text —
    /// the sheet renders it as a short paragraph.
    static func answer(question: String, context: MovieCoachContext) async throws -> String {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *), isReady else { throw CoachError.unavailable }

        let session = LanguageModelSession(instructions: instructions)
        let prompt = """
        CONTEXT:
        \(context.promptText)

        The user asks: "\(question)"

        Answer in one to three short sentences using only the context above. \
        If the context doesn't contain what's needed to answer confidently, \
        say briefly what you can tell from what's known instead of guessing.
        """

        let response = try await session.respond(
            to: prompt,
            options: GenerationOptions(temperature: 0.5, maximumResponseTokens: responseTokenLimit)
        )
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw CoachError.unavailable
        #endif
    }

    /// Suggested questions, tailored to movie vs series so the sheet is
    /// useful without typing.
    static func suggestedQuestions(for context: MovieCoachContext) -> [String] {
        var questions = [String(localized: "Is this a good choice tonight?", comment: "Movie Coach suggested question"),
                         String(localized: "Is it slow?", comment: "Movie Coach suggested question: is the pacing slow")]

        if context.kind == "series" {
            questions.append(String(localized: "Is it a big commitment?", comment: "Movie Coach suggested question: does the series take a lot of time"))
        } else if let runtime = context.runtimeMinutes, runtime >= 140 {
            questions.append(String(localized: "Is it worth the runtime?", comment: "Movie Coach suggested question: is the long film worth its length"))
        }
        // Horror, Thriller, Mystery. By id: `genres` is in the app's TMDB
        // language.
        if context.genreIDs.contains(where: [27, 53, 9648].contains) {
            questions.append(String(localized: "Is it scary?", comment: "Movie Coach suggested question"))
        }
        if !context.similarSaved.isEmpty {
            questions.append(String(localized: "Is it similar to something I like?", comment: "Movie Coach suggested question"))
        }
        questions.append(String(localized: "Why should I watch this?", comment: "Movie Coach suggested question"))

        return Array(questions.prefix(5))
    }
}
