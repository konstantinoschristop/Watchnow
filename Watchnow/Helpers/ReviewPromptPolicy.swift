//
//  ReviewPromptPolicy.swift
//  Watchnow
//
//  When it is fair to ask someone to rate the app.
//
//  iOS allows three prompts a year and remembers nothing about why you
//  spent them, so the only way to get a good rating is to ask at a moment
//  the user is already pleased — and never at any other. The three triggers
//  here are all moments of payoff rather than moments of effort: a Movie
//  Night that ended in a match, finishing something they were tracking, and
//  a watchlist that has grown enough to be worth having.
//
//  Pure, so every gate below is provable. The shell that spends the prompt
//  is `ReviewRequestManager`.
//

import Foundation

/// The three moments worth asking at.
enum ReviewTrigger: String, Sendable, CaseIterable {

    /// Movie Night ended in a match and the user is opening it. The single
    /// best moment the app has: a decision was made and they liked it.
    case movieNightMatch

    /// They finished something they had been tracking — the loop closing.
    case markedWatched

    /// The watchlist has reached a size where it is doing its job.
    case savedTitle
}

enum ReviewPromptPolicy {

    /// Apple's own backstop is three a year. Asking at most every four
    /// months keeps two in reserve for a later version that deserves them.
    static let throttle: TimeInterval = 120 * 86_400

    /// Nobody knows whether they like an app on day one, and an install
    /// that gets asked immediately is an install that gets a one-star
    /// answer or deletes the app.
    static let settlingPeriod: TimeInterval = 48 * 3_600

    static let watchedThreshold = 3
    static let savedThreshold = 3

    struct Inputs: Equatable {
        var trigger: ReviewTrigger
        /// When the app was first opened. Nil for an install predating this
        /// bookkeeping — treated as "don't know", which means don't ask.
        var firstLaunchedAt: Date?
        var lastPromptedAt: Date?
        /// True for the session in which the app was first opened.
        var isFirstSession: Bool
        var savedCount: Int
        var watchedCount: Int
        var now: Date

        init(trigger: ReviewTrigger,
             firstLaunchedAt: Date?,
             lastPromptedAt: Date? = nil,
             isFirstSession: Bool = false,
             savedCount: Int = 0,
             watchedCount: Int = 0,
             now: Date = Date()) {
            self.trigger = trigger
            self.firstLaunchedAt = firstLaunchedAt
            self.lastPromptedAt = lastPromptedAt
            self.isFirstSession = isFirstSession
            self.savedCount = savedCount
            self.watchedCount = watchedCount
            self.now = now
        }
    }

    static func shouldAsk(_ inputs: Inputs) -> Bool {
        // Never during the first session, whatever else is true. The
        // settling period below usually covers this, but not if the device
        // clock is wrong or the install date was never recorded — and the
        // first session is the one where being asked is most obviously
        // premature.
        guard !inputs.isFirstSession else { return false }

        guard let firstLaunchedAt = inputs.firstLaunchedAt,
              inputs.now.timeIntervalSince(firstLaunchedAt) >= settlingPeriod
        else { return false }

        if let lastPromptedAt = inputs.lastPromptedAt,
           inputs.now.timeIntervalSince(lastPromptedAt) < throttle {
            return false
        }

        return qualifies(inputs)
    }

    /// Whether this particular moment has earned the ask.
    ///
    /// A match needs no threshold: it is the payoff of a whole session the
    /// user chose to play. The other two are ordinary actions, so they only
    /// count once they have accumulated into something.
    private static func qualifies(_ inputs: Inputs) -> Bool {
        switch inputs.trigger {
        case .movieNightMatch: return true
        case .markedWatched:   return inputs.watchedCount >= watchedThreshold
        case .savedTitle:      return inputs.savedCount >= savedThreshold
        }
    }
}
