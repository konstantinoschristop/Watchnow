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
        case .greatPick:        return "This one's for you"
        case .goodPick:         return "A solid option tonight"
        case .maybeLater:       return "Right film, wrong moment"
        case .notIdealRightNow: return "There are better calls tonight"
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

    @Guide(description: "One to three short sentences explaining the verdict in a warm, direct voice. No spoilers, no synopsis retelling, no mention of data or preferences as a concept.")
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
    /// Bumping discards answers generated under any older prompt.
    static let promptVersion = 4

    /// Coach only speaks up once it has enough saved titles to actually know
    /// the user's taste. Below this it would be guessing dressed up as advice,
    /// so the card shows a short "save a few more" hint instead.
    static let minimumWatchlistSize = 5

    static var savedTitleCount: Int { WatchlistManager.watchlist.count }

    static var hasEnoughHistory: Bool { savedTitleCount >= minimumWatchlistSize }

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
        case .available:      return .ready
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
    private static let instructions = """
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
    - Weigh practical fit: runtime, number of seasons, and whether it is \
    already out or still unreleased.
    - Never mention data, context, preferences-as-a-concept, algorithms, or \
    that you are an AI. Never say "based on your preferences" or "according \
    to the data". Just speak naturally, like a friend with good taste.
    """

    // MARK: Verdict

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

        The verdict has already been decided: "\(call.verdict.headline)".
        The reason is: \(call.reason).

        Write one to three short sentences telling the user that, in your own \
        natural wording. Agree with the verdict — do not argue against it or \
        soften it into a different conclusion. Lead with what matters most, \
        and only mention facts from the context.
        """

        let response = try await session.respond(
            to: prompt,
            generating: MovieCoachResponse.self,
            options: GenerationOptions(temperature: 0.5, maximumResponseTokens: 220)
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
            options: GenerationOptions(temperature: 0.5, maximumResponseTokens: 220)
        )
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw CoachError.unavailable
        #endif
    }

    /// Suggested questions, tailored to movie vs series so the sheet is
    /// useful without typing.
    static func suggestedQuestions(for context: MovieCoachContext) -> [String] {
        var questions = ["Is this a good choice tonight?", "Is it slow?"]

        if context.kind == "series" {
            questions.append("Is it a big commitment?")
        } else if let runtime = context.runtimeMinutes, runtime >= 140 {
            questions.append("Is it worth the runtime?")
        }
        if context.genres.contains(where: { ["Horror", "Thriller", "Mystery"].contains($0) }) {
            questions.append("Is it scary?")
        }
        if !context.similarSaved.isEmpty {
            questions.append("Is it similar to something I like?")
        }
        questions.append("Why should I watch this?")

        return Array(questions.prefix(5))
    }
}
