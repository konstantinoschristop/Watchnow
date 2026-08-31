//
//  WhatsNewViewModel.swift
//  Watchnow
//
//  Presentation state for the "While You Were Away" briefing.
//
//  All policy questions (was the user away? which changes are unseen?) are
//  answered by `WatchlistChangeStore`; ranking and per-title collapsing by
//  `ChangeClassifier`. This class just sequences them: evaluate at launch
//  with whatever is cached, kick the background sync, and re-evaluate once
//  when the sync lands something new — so a user returning after days sees
//  fresh findings on the same return, without the UI ever waiting on the
//  network.
//
//  A shared singleton (like `DeepLinkRouter`) so the DEBUG tooling can
//  drive the exact same instance ContentView presents from — fake data
//  flows through the identical pipeline as real changes.
//

import Foundation
import Combine

@MainActor
final class WhatsNewViewModel: ObservableObject {

    static let shared = WhatsNewViewModel()

    /// Drives the sheet in ContentView.
    @Published var isPresented = false

    /// The ranked, per-title-collapsed changes on screen — at most
    /// `maxPresented`.
    @Published private(set) var briefing: [WatchlistChange] = []

    /// Every unseen change behind the briefing, for the "5 of 12" line.
    private(set) var totalUnseenCount = 0

    /// At most ~5 cards, ever. Enough to feel looked-after, few enough to
    /// read in ten seconds.
    static let maxPresented = 5

    /// How long after launch the briefing may still interrupt. Past this the
    /// user has moved on and a modal would be an ambush.
    static var presentationWindow: TimeInterval = 12

    private var isChecking = false

    /// The ids that made up the briefing currently on screen, captured when
    /// it was assembled. Dismissal retires exactly these.
    private var presentedBatchIDs: [String] = []

    // Internal (not private) so tests can build isolated instances;
    // production code uses `shared`.
    init() {}

    var isSingleChange: Bool { briefing.count == 1 }

    var headline: String {
        isSingleChange ? "Something changed" : "While You Were Away"
    }

    var subheadline: String {
        if isSingleChange { return "One update in your watchlist" }
        return "\(briefing.count) things changed in your watchlist"
    }

    /// "Showing 5 of 12" — only when there's genuinely more than shown.
    var overflowText: String? {
        guard totalUnseenCount > briefing.count else { return nil }
        return "Showing \(briefing.count) of \(totalUnseenCount) updates"
    }

    // MARK: - Launch flow

    /// Called when the app launches or returns to the foreground. Decides
    /// everything up front from cached state, then lets the background sync
    /// improve the answer once — on the same return, never mid-reading.
    func checkOnLaunch() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        // Away-ness must be read *before* this open is recorded, and it
        // stays fixed for the whole evaluation: the user either came back
        // from an absence or they didn't.
        let wasAway = WatchlistChangeStore.wasAway()
        let launchedAt = Date()

        // Anything already banked can be shown right now.
        var presented = attemptPresentation(wasAway: wasAway)

        // Nothing is pre-computed — the app has no background refresh, so on
        // a return-from-away launch this sync is what *creates* the
        // briefing. Run it at full tilt in that case.
        let foundNew = await WatchlistChangeMonitor.syncIfNeeded(urgent: wasAway)

        // A sheet that arrives long after launch lands on top of someone
        // already browsing. Past the window we stay quiet and let the next
        // open deliver it.
        if foundNew, !presented,
           Date().timeIntervalSince(launchedAt) < Self.presentationWindow {
            presented = attemptPresentation(wasAway: wasAway)
        }

        // Recording the open spends the user's "away" credit. Only spend it
        // once the briefing has actually been delivered — or when there was
        // nothing to deliver. Otherwise the briefing stays owed and shows on
        // the next open, straight from cache, instead of waiting for another
        // full absence.
        let owed = wasAway && !presented && !WatchlistChangeStore.unseenChanges().isEmpty
        if !owed {
            WatchlistChangeStore.recordMeaningfulLaunch()
        }
    }

    /// The one place the sheet decides to appear. Returns whether it did.
    @discardableResult
    func attemptPresentation(wasAway: Bool, now: Date = Date()) -> Bool {
        guard wasAway, !isPresented else { return false }
        return presentUnseen(now: now)
    }

    /// Load, rank and cap the unseen changes; present when there are any.
    /// Shared by the launch gate and the DEBUG "Show What's New" button so
    /// both run the identical pipeline.
    @discardableResult
    func presentUnseen(now: Date = Date()) -> Bool {
        let unseen = WatchlistChangeStore.unseenChanges(now: now)
        let ranked = ChangeClassifier.ranked(unseen)
        guard !ranked.isEmpty else { return false }

        briefing = Array(ranked.prefix(Self.maxPresented))
        totalUnseenCount = ranked.count
        // Everything unseen *right now* is this briefing's batch — including
        // the per-title changes that `ranked` collapsed away and the
        // overflow past `maxPresented`. Anything filed after this moment (the
        // launch sync often lands while the sheet is open) belongs to the
        // next briefing, not this one.
        presentedBatchIDs = unseen.map(\.id)
        isPresented = true
        return true
    }

    // MARK: - Dismissal

    /// Sheet went away (Done, swipe, or tapping through to a title): the
    /// batch that was on screen is spent — including the overflow that
    /// wasn't shown. Changes discovered *after* it was assembled survive and
    /// lead the next briefing.
    func briefingDismissed() {
        WatchlistChangeStore.markSeen(presentedBatchIDs)
        presentedBatchIDs = []
        briefing = []
        totalUnseenCount = 0
    }

    /// Tap-through on a card: close the sheet, then route through the
    /// existing deeplink machinery once the dismissal has settled — the
    /// same path a notification tap takes into ContentDetailsView.
    func open(_ change: WatchlistChange) {
        isPresented = false
        let link = change.deepLink
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            DeepLinkRouter.shared.handle(link)
        }
    }

    // MARK: - Taste hint

    /// Movie Coach's cameo: a deterministic one-liner when the changed
    /// title's genres sit squarely in what the user saves most. No
    /// Foundation Models involved — the briefing works identically without
    /// them. Only the focused single-change layout shows this.
    func tasteHint(for change: WatchlistChange) -> String? {
        let watchlist = WatchlistManager.watchlist

        var counts: [String: Int] = [:]
        for item in watchlist {
            for genreID in item.genre_ids ?? [] {
                if let name = tmdbGenreNames[genreID] { counts[name, default: 0] += 1 }
            }
        }
        let topGenres = counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(3)
            .map(\.key)

        let titleGenres = watchlist.first { $0.id == change.mediaID }?.genre_ids ?? []
        let overlap = titleGenres.compactMap { tmdbGenreNames[$0] }.filter(topGenres.contains)

        guard let genre = overlap.first else { return nil }
        return "Right in your \(genre) lane."
    }
}
