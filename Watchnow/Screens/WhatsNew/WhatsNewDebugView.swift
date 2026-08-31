//
//  WhatsNewDebugView.swift
//  Watchnow
//
//  DEBUG-only test bench for "While You Were Away".
//
//  Real TMDB changes are rare and unrepeatable, so this menu fabricates
//  `WatchlistChange` values — but everything it makes enters through
//  `WatchlistChangeStore.add`, exactly where the real monitor files its
//  findings, and is presented by the real `WhatsNewViewModel` pipeline
//  (ranking, per-title collapse, seen-tracking, the 5-card cap). There is
//  no fake view and no bypass: if it looks right here, it is right.
//
//  The whole file compiles away in Release.
//

#if DEBUG

import SwiftUI

// MARK: - Scenarios

enum WhatsNewDebugScenario: String, CaseIterable, Identifiable {
    case oneTrailer      = "One Trailer"
    case oneReleaseDate  = "One Release Date"
    case oneStreaming    = "One Streaming"
    case oneEpisode      = "One Episode"
    case multiple        = "Multiple Changes"
    case many            = "Many Changes (12)"
    case sameTitleDedup  = "Same Title ×3 (Dedup)"
    case mixedPriority   = "Mixed Priority"
    case withReminder    = "Reminder + Change"
    case alreadySeen     = "Already Seen"
    case oldChanges      = "Old Changes (Stale)"

    var id: String { rawValue }
}

// MARK: - Generator

@MainActor
enum WhatsNewDebug {

    private struct Fixture {
        let id: Int
        let title: String
        let mediaType: String
        var posterPath: String?
        var backdropPath: String?
    }

    /// Real, recognisable TMDB titles so card tap-through lands on real
    /// details pages even on a fresh install.
    private static let fallbacks: [Fixture] = [
        Fixture(id: 634649, title: "Spider-Man: No Way Home", mediaType: "movie"),
        Fixture(id: 693134, title: "Dune: Part Two", mediaType: "movie"),
        Fixture(id: 66732,  title: "Stranger Things", mediaType: "tv"),
        Fixture(id: 414906, title: "The Batman", mediaType: "movie"),
        Fixture(id: 157336, title: "Interstellar", mediaType: "movie"),
        Fixture(id: 1396,   title: "Breaking Bad", mediaType: "tv"),
        Fixture(id: 27205,  title: "Inception", mediaType: "movie"),
        Fixture(id: 872585, title: "Oppenheimer", mediaType: "movie"),
        Fixture(id: 94997,  title: "House of the Dragon", mediaType: "tv"),
        Fixture(id: 603,    title: "The Matrix", mediaType: "movie"),
        Fixture(id: 62560,  title: "Mr. Robot", mediaType: "tv"),
        Fixture(id: 76600,  title: "Avatar: The Way of Water", mediaType: "movie")
    ]

    /// Watchlist titles first (the user's own content), then the fallbacks,
    /// deduped by id. Fixtures missing artwork fetch it from the real
    /// details endpoint so the briefing demos with real posters/backdrops —
    /// a debug-only nicety; real changes get artwork from their snapshots.
    private static func fixtures(_ count: Int, using service: ServiceInvocation) async -> [Fixture] {
        var pool: [Fixture] = WatchlistManager.watchlist.compactMap { item in
            guard let id = item.id else { return nil }
            return Fixture(id: id,
                           title: item.getResultTitle(),
                           mediaType: item.inferredScreenType.rawValue,
                           posterPath: item.poster_path,
                           backdropPath: item.backdrop_path)
        }
        var seen = Set(pool.map(\.id))
        for fallback in fallbacks where !seen.contains(fallback.id) {
            pool.append(fallback)
            seen.insert(fallback.id)
        }

        var picked = Array(pool.prefix(count))
        for index in picked.indices where picked[index].posterPath == nil || picked[index].backdropPath == nil {
            let fixture = picked[index]
            let type: ScreenTypes = fixture.mediaType == "tv" ? .tv : .movie
            guard let details = try? await service.fetchDetails(screenType: type, id: String(fixture.id)) else { continue }
            picked[index].posterPath = fixture.posterPath ?? details.poster_path
            picked[index].backdropPath = fixture.backdropPath ?? details.backdrop_path
        }
        return picked
    }

    private static func change(_ kind: WatchlistChangeKind,
                               fixture: Fixture,
                               metadata: ChangeMetadata,
                               detail: String,
                               reminder: Bool = false,
                               occurredAt: Date = Date()) -> WatchlistChange {
        WatchlistChange(
            id: WatchlistChange.makeID(mediaType: fixture.mediaType,
                                       mediaID: fixture.id,
                                       kind: kind,
                                       detail: detail),
            mediaID: fixture.id,
            mediaType: fixture.mediaType,
            kind: kind,
            title: fixture.title,
            posterPath: fixture.posterPath,
            backdropPath: fixture.backdropPath,
            occurredAt: occurredAt.timeIntervalSince1970,
            metadata: metadata,
            hasReminder: reminder
        )
    }

    private static func sampleChange(_ kind: WatchlistChangeKind,
                                     fixture: Fixture,
                                     reminder: Bool = false,
                                     occurredAt: Date = Date()) -> WatchlistChange {
        switch kind {
        case .newTrailer:
            return change(.newTrailer, fixture: fixture,
                          metadata: ChangeMetadata(videoKey: "6ZfuNTqbHE8", videoName: "Official Trailer"),
                          detail: "debug.trailer", reminder: reminder, occurredAt: occurredAt)
        case .releaseDateChanged:
            return change(.releaseDateChanged, fixture: fixture,
                          metadata: ChangeMetadata(oldDate: "2026-11-20", newDate: "2026-12-18"),
                          detail: "2026-12-18", reminder: reminder, occurredAt: occurredAt)
        case .streamingAvailability:
            return change(.streamingAvailability, fixture: fixture,
                          metadata: ChangeMetadata(providerName: "Netflix"),
                          detail: "8", reminder: reminder, occurredAt: occurredAt)
        case .newEpisode:
            return change(.newEpisode, fixture: fixture,
                          metadata: ChangeMetadata(seasonNumber: 3, episodeNumber: 4,
                                                   episodeName: "The Turning Point", airDate: "2026-08-28"),
                          detail: "debug.episode", reminder: reminder, occurredAt: occurredAt)
        case .newSeason:
            return change(.newSeason, fixture: fixture,
                          metadata: ChangeMetadata(seasonNumber: 5),
                          detail: "5", reminder: reminder, occurredAt: occurredAt)
        case .released:
            return change(.released, fixture: fixture,
                          metadata: ChangeMetadata(newDate: "2026-08-21"),
                          detail: "released", reminder: reminder, occurredAt: occurredAt)
        case .episodeDateChanged:
            return change(.episodeDateChanged, fixture: fixture,
                          metadata: ChangeMetadata(oldDate: "2026-09-01", seasonNumber: 3,
                                                   episodeNumber: 5, airDate: "2026-09-12"),
                          detail: "debug.epdate", reminder: reminder, occurredAt: occurredAt)
        }
    }

    /// Build a scenario and file it through the real store. Returns a
    /// human-readable summary for the debug UI.
    static func generate(_ scenario: WhatsNewDebugScenario,
                         using service: ServiceInvocation = ServiceInvocation()) async -> String {
        switch scenario {
        case .oneTrailer:
            let added = WatchlistChangeStore.add([sampleChange(.newTrailer, fixture: await fixtures(1, using: service)[0])])
            return summary(added, of: 1)

        case .oneReleaseDate:
            let added = WatchlistChangeStore.add([sampleChange(.releaseDateChanged, fixture: await fixtures(1, using: service)[0])])
            return summary(added, of: 1)

        case .oneStreaming:
            let added = WatchlistChangeStore.add([sampleChange(.streamingAvailability, fixture: await fixtures(1, using: service)[0])])
            return summary(added, of: 1)

        case .oneEpisode:
            let fixture = await fixtures(8, using: service).first { $0.mediaType == "tv" } ?? fallbacks[2]
            let added = WatchlistChangeStore.add([sampleChange(.newEpisode, fixture: fixture)])
            return summary(added, of: 1)

        case .multiple:
            let f = await fixtures(4, using: service)
            let added = WatchlistChangeStore.add([
                sampleChange(.newTrailer, fixture: f[0]),
                sampleChange(.releaseDateChanged, fixture: f[1]),
                sampleChange(.newEpisode, fixture: f[2]),
                sampleChange(.streamingAvailability, fixture: f[3])
            ])
            return summary(added, of: 4)

        case .many:
            let f = await fixtures(12, using: service)
            let kinds = WatchlistChangeKind.allCases
            let changes = f.enumerated().map { index, fixture in
                sampleChange(kinds[index % kinds.count], fixture: fixture)
            }
            let added = WatchlistChangeStore.add(changes)
            return summary(added, of: changes.count) + " Briefing should cap at 5."

        case .sameTitleDedup:
            let fixture = await fixtures(1, using: service)[0]
            let added = WatchlistChangeStore.add([
                sampleChange(.releaseDateChanged, fixture: fixture),
                sampleChange(.newTrailer, fixture: fixture),
                sampleChange(.released, fixture: fixture)
            ])
            return summary(added, of: 3) + " Should collapse to ONE card (trailer wins)."

        case .mixedPriority:
            let f = await fixtures(5, using: service)
            let added = WatchlistChangeStore.add([
                sampleChange(.episodeDateChanged, fixture: f[0]),
                sampleChange(.released, fixture: f[1]),
                sampleChange(.streamingAvailability, fixture: f[2]),
                sampleChange(.newSeason, fixture: f[3]),
                sampleChange(.newTrailer, fixture: f[4])
            ])
            return summary(added, of: 5) + " Expect: streaming, trailer, season, released, air date."

        case .withReminder:
            let f = await fixtures(2, using: service)
            let added = WatchlistChangeStore.add([
                sampleChange(.releaseDateChanged, fixture: f[0], reminder: true),
                sampleChange(.streamingAvailability, fixture: f[1])
            ])
            return summary(added, of: 2) + " The reminder title must rank first."

        case .alreadySeen:
            let seen = sampleChange(.newTrailer, fixture: await fixtures(1, using: service)[0])
            WatchlistChangeStore.add([seen])
            WatchlistChangeStore.markSeen([seen.id])
            return "Added 1, marked it seen — it must NOT appear."

        case .oldChanges:
            let stale = sampleChange(.newTrailer, fixture: await fixtures(1, using: service)[0],
                                     occurredAt: Date().addingTimeInterval(-40 * 24 * 3600))
            let added = WatchlistChangeStore.add([stale])
            return "Tried 1 stale change; store accepted \(added) — stale news is rejected."
        }
    }

    private static func summary(_ added: Int, of total: Int) -> String {
        "Filed \(added) of \(total) through the real store" +
        (added < total ? " (rest were already seen/pending — Reset to replay)." : ".")
    }
}

// MARK: - Debug menu

struct WhatsNewDebugView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var status = ""
    @State private var refreshTick = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Show What's New") { showBriefing(force: true) }
                    Button("Run Real Launch Check") { showBriefing(force: false) }
                    Button("Run Real Sync Now") {
                        status = "Syncing watchlist against TMDB…"
                        Task {
                            let found = await WatchlistChangeMonitor.syncIfNeeded(force: true)
                            status = found ? "Sync stored new changes." : "Sync found nothing new."
                            refreshTick += 1
                        }
                    }
                } header: {
                    Text("Present")
                } footer: {
                    Text("\"Show\" presents whatever is unseen through the real pipeline. \"Launch Check\" also applies the away-for-24h gate.")
                }

                Section("Generate Scenario") {
                    ForEach(WhatsNewDebugScenario.allCases) { scenario in
                        Button(scenario.rawValue) {
                            status = "Generating…"
                            Task {
                                status = await WhatsNewDebug.generate(scenario)
                                refreshTick += 1
                            }
                        }
                    }
                }

                Section("Time Travel") {
                    Button("Simulate Returning After 1 Day") {
                        WatchlistChangeStore.debugShiftLastLaunch(by: 25 * 3600)
                        status = "Last open moved 25h back — the launch gate now sees you as away."
                    }
                    Button("Simulate Returning After 7 Days") {
                        WatchlistChangeStore.debugShiftLastLaunch(by: 7 * 24 * 3600)
                        status = "Last open moved 7 days back."
                    }
                }

                Section {
                    Button("Mark All Seen") {
                        WatchlistChangeStore.markAllSeen()
                        status = "All pending changes marked seen."
                        refreshTick += 1
                    }
                    Button("Reset What's New State", role: .destructive) {
                        WatchlistChangeStore.reset()
                        status = "Snapshots, changes, seen ids and timestamps wiped."
                        refreshTick += 1
                    }
                } header: {
                    Text("State")
                } footer: {
                    stateFooter
                }

                if !status.isEmpty {
                    Section("Result") {
                        Text(status)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("What's New Testing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var stateFooter: some View {
        // refreshTick forces this to re-read the store after actions.
        let unseen = WatchlistChangeStore.unseenChanges().count
        return Text("Unseen: \(unseen) · Seen: \(WatchlistChangeStore.seenCount) · Snapshots: \(WatchlistChangeStore.snapshotCount) · Tick \(refreshTick)")
            .font(.caption2)
    }

    /// Dismiss this sheet first — the briefing presents from ContentView's
    /// context — then run the real presentation path.
    private func showBriefing(force: Bool) {
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            let vm = WhatsNewViewModel.shared
            let shown = force
                ? vm.presentUnseen()
                : vm.attemptPresentation(wasAway: WatchlistChangeStore.wasAway())
            if !shown {
                // Nothing to show is a *correct* outcome (STATE C) — make it
                // visible to the tester without inventing a fake empty sheet.
                print("[WhatsNewDebug] Gate declined to present: no unseen changes"
                      + (force ? "." : " or user not away long enough."))
            }
        }
    }
}

#endif
