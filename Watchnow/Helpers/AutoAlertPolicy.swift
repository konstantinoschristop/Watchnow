//
//  AutoAlertPolicy.swift
//  Watchnow
//
//  Whether a saved title should produce automatic alerts, and of which
//  kinds.
//
//  Pure: it reads nothing and writes nothing, so the answer is entirely
//  determined by the values handed in. That is what lets the whole matrix be
//  tested without a device, a store or a clock — and it is why the caps and
//  quiet hours that follow in the next phase can be trusted.
//
//  The rule is deliberately boring: saving opts you in, and the two global
//  switches plus a per-title exception are the only things that can take it
//  away again.
//

import Foundation

/// The automatic alerts this release can produce.
///
/// Manual bell reminders are deliberately absent. Those are the user's own,
/// are scheduled by `ReminderManager`, and no policy here gets to withdraw
/// one.
enum AlertKind: String, Codable, Sendable, CaseIterable {

    /// A saved series' next episode airs today.
    case episode

    /// A saved title started streaming on a service the user has.
    case streaming
}

enum AutoAlertPolicy {

    /// Everything the decision depends on.
    ///
    /// A struct rather than four loose `Bool` arguments, because four
    /// same-typed parameters in a row is an invitation to transpose two of
    /// them and never find out.
    struct Inputs: Equatable, Sendable {

        /// Alerts only ever follow from a save. Nothing else subscribes.
        var isSaved: Bool
        var episodeAlertsEnabled: Bool
        var streamingAlertsEnabled: Bool
        /// The user switched this specific title off.
        var isOptedOut: Bool

        init(isSaved: Bool,
             episodeAlertsEnabled: Bool,
             streamingAlertsEnabled: Bool,
             isOptedOut: Bool) {
            self.isSaved = isSaved
            self.episodeAlertsEnabled = episodeAlertsEnabled
            self.streamingAlertsEnabled = streamingAlertsEnabled
            self.isOptedOut = isOptedOut
        }
    }

    /// Which alerts this title may produce. Empty means silence.
    static func alertKinds(for inputs: Inputs) -> Set<AlertKind> {
        guard inputs.isSaved, !inputs.isOptedOut else { return [] }

        var kinds: Set<AlertKind> = []
        if inputs.episodeAlertsEnabled { kinds.insert(.episode) }
        if inputs.streamingAlertsEnabled { kinds.insert(.streaming) }
        return kinds
    }

    /// Whether the title will produce any alert at all — the state the
    /// per-title bell renders.
    ///
    /// Note this is false when both global switches are off, even though the
    /// title itself carries no exception. That is the honest answer: the bell
    /// must not claim an alert the app will never send.
    static func isFollowed(_ inputs: Inputs) -> Bool {
        !alertKinds(for: inputs).isEmpty
    }
}
