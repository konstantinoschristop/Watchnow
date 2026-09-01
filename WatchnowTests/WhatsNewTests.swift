//
//  WhatsNewTests.swift
//  WatchnowTests
//
//  Unit coverage for the "While You Were Away" pipeline: the classifier's
//  meaningful-vs-noise judgement, the store's seen/stale bookkeeping, the
//  presentation gate, and the view model's ranking/capping.
//
//  No network anywhere — classifier inputs are hand-built fixtures with
//  deterministic dates, and the store runs against the test host's
//  UserDefaults, wiped before every test via `WatchlistChangeStore.reset()`.
//

import XCTest
@testable import Watchnow

// A fixed "today" for every test: 2026-08-30 00:00 UTC.
private let fixedNow: Date = {
    let fmt = DateFormatter()
    fmt.calendar = Calendar(identifier: .iso8601)
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.timeZone = TimeZone(secondsFromGMT: 0)
    fmt.dateFormat = "yyyy-MM-dd"
    return fmt.date(from: "2026-08-30")!
}()

// MARK: - Fixture builders

private func makeSnapshot(mediaType: String = "movie",
                          id: Int = 100,
                          title: String = "Fixture Film",
                          releaseDate: String? = nil,
                          status: String? = nil,
                          seasonCount: Int? = nil,
                          lastEpisodeID: Int? = nil,
                          nextEpisodeID: Int? = nil,
                          nextEpisodeAirDate: String? = nil,
                          videoIDs: [String] = [],
                          providerIDs: [Int] = []) -> WatchlistSnapshot {
    WatchlistSnapshot(mediaID: id,
                      mediaType: mediaType,
                      title: title,
                      posterPath: nil,
                      backdropPath: nil,
                      releaseDate: releaseDate,
                      status: status,
                      seasonCount: seasonCount,
                      episodeCount: nil,
                      lastEpisodeID: lastEpisodeID,
                      nextEpisodeID: nextEpisodeID,
                      nextEpisodeAirDate: nextEpisodeAirDate,
                      videoIDs: videoIDs,
                      providerIDs: providerIDs,
                      lastCheckedAt: fixedNow.timeIntervalSince1970 - 7 * 24 * 3600)
}

private func makeDetails(releaseDate: String? = nil,
                         firstAirDate: String? = nil,
                         status: String? = nil,
                         seasons: Int? = nil,
                         episodes: Int? = nil,
                         lastEpisode: Episode? = nil,
                         nextEpisode: Episode? = nil,
                         posterPath: String? = nil,
                         overview: String? = nil) -> ResultDetailsResponse {
    ResultDetailsResponse(genres: nil, seasons: nil, number_of_episodes: episodes,
                          number_of_seasons: seasons, name: nil, id: nil, imdb_id: nil,
                          tagline: nil, spoken_languages: nil, revenue: nil, budget: nil,
                          runtime: nil, belongs_to_collection: nil, status: status,
                          homepage: nil, created_by: nil, release_date: releaseDate,
                          first_air_date: firstAirDate, overview: overview, vote_average: nil,
                          vote_count: nil, poster_path: posterPath, backdrop_path: nil,
                          title: nil, last_episode_to_air: lastEpisode,
                          next_episode_to_air: nextEpisode)
}

private func makeEpisode(id: Int, season: Int, episode: Int,
                         airDate: String?, name: String = "Episode") -> Episode {
    Episode(id: id, name: name, overview: nil, still_path: nil,
            vote_average: nil, vote_count: nil, air_date: airDate,
            episode_number: episode, season_number: season)
}

private func makeVideo(id: String, key: String = "ytkey", type: String = "Trailer",
                       official: Bool = true) -> VideoModelResult {
    VideoModelResult(id: id, key: key, name: "Video \(id)", site: "YouTube",
                     official: official, type: type)
}

private func makeChange(kind: WatchlistChangeKind,
                        id: Int = 1,
                        mediaType: String = "movie",
                        title: String = "Title",
                        reminder: Bool = false,
                        occurredAt: Date = fixedNow) -> WatchlistChange {
    WatchlistChange(id: WatchlistChange.makeID(mediaType: mediaType, mediaID: id,
                                               kind: kind, detail: "test"),
                    mediaID: id,
                    mediaType: mediaType,
                    kind: kind,
                    title: title,
                    posterPath: nil,
                    backdropPath: nil,
                    occurredAt: occurredAt.timeIntervalSince1970,
                    metadata: ChangeMetadata(),
                    hasReminder: reminder)
}

// MARK: - Classifier

@MainActor
final class ChangeClassifierTests: XCTestCase {

    func testNewTrailerIsMeaningful() {
        let snapshot = makeSnapshot(videoIDs: ["old"])
        let fresh = ChangeClassifier.Fresh(videos: [makeVideo(id: "old"),
                                                    makeVideo(id: "new", key: "abc123")])
        let changes = ChangeClassifier.changes(from: snapshot, fresh: fresh,
                                               hasReminder: false, now: fixedNow)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.kind, .newTrailer)
        XCTAssertEqual(changes.first?.metadata.videoKey, "abc123")
    }

    func testNonTrailerVideosAreIgnored() {
        let snapshot = makeSnapshot(videoIDs: [])
        let fresh = ChangeClassifier.Fresh(videos: [makeVideo(id: "bts", type: "Behind the Scenes"),
                                                    makeVideo(id: "clip", type: "Clip")])
        let changes = ChangeClassifier.changes(from: snapshot, fresh: fresh,
                                               hasReminder: false, now: fixedNow)
        XCTAssertTrue(changes.isEmpty)
    }

    func testCosmeticEditsProduceNothing() {
        // Poster and overview changed — exactly the noise the classifier
        // must never surface.
        let snapshot = makeSnapshot(releaseDate: "2026-12-18", status: "Post Production",
                                    videoIDs: ["v1"], providerIDs: [8])
        let fresh = ChangeClassifier.Fresh(
            details: makeDetails(releaseDate: "2026-12-18", status: "Post Production",
                                 posterPath: "/brand-new-poster.jpg",
                                 overview: "A freshly rewritten overview."),
            videos: [makeVideo(id: "v1")],
            providerIDs: [8]
        )
        let changes = ChangeClassifier.changes(from: snapshot, fresh: fresh,
                                               hasReminder: false, now: fixedNow)
        XCTAssertTrue(changes.isEmpty)
    }

    func testReleaseDateChangeIsMeaningful() {
        let snapshot = makeSnapshot(releaseDate: "2026-11-20")
        let fresh = ChangeClassifier.Fresh(details: makeDetails(releaseDate: "2026-12-18"))
        let changes = ChangeClassifier.changes(from: snapshot, fresh: fresh,
                                               hasReminder: false, now: fixedNow)
        XCTAssertEqual(changes.first?.kind, .releaseDateChanged)
        XCTAssertEqual(changes.first?.metadata.oldDate, "2026-11-20")
        XCTAssertEqual(changes.first?.metadata.newDate, "2026-12-18")
    }

    func testOldFilmDateCorrectionIsIgnored() {
        let snapshot = makeSnapshot(releaseDate: "2009-01-15")
        let fresh = ChangeClassifier.Fresh(details: makeDetails(releaseDate: "2009-01-17"))
        let changes = ChangeClassifier.changes(from: snapshot, fresh: fresh,
                                               hasReminder: false, now: fixedNow)
        XCTAssertTrue(changes.isEmpty)
    }

    func testStreamingAdditionIsMeaningful() {
        let snapshot = makeSnapshot(providerIDs: [8])
        let fresh = ChangeClassifier.Fresh(providerIDs: [8, 337],
                                           providerNames: [8: "Netflix", 337: "Disney+"])
        let changes = ChangeClassifier.changes(from: snapshot, fresh: fresh,
                                               hasReminder: false, now: fixedNow)
        XCTAssertEqual(changes.first?.kind, .streamingAvailability)
        XCTAssertEqual(changes.first?.metadata.providerName, "Disney+")
    }

    func testStreamingRemovalIsIgnored() {
        let snapshot = makeSnapshot(providerIDs: [8, 337])
        let fresh = ChangeClassifier.Fresh(providerIDs: [8])
        let changes = ChangeClassifier.changes(from: snapshot, fresh: fresh,
                                               hasReminder: false, now: fixedNow)
        XCTAssertTrue(changes.isEmpty)
    }

    func testNewEpisodeIsMeaningful() {
        let snapshot = makeSnapshot(mediaType: "tv", lastEpisodeID: 501)
        let fresh = ChangeClassifier.Fresh(
            details: makeDetails(lastEpisode: makeEpisode(id: 502, season: 3, episode: 4,
                                                          airDate: "2026-08-28"))
        )
        let changes = ChangeClassifier.changes(from: snapshot, fresh: fresh,
                                               hasReminder: false, now: fixedNow)
        XCTAssertEqual(changes.first?.kind, .newEpisode)
        XCTAssertEqual(changes.first?.metadata.seasonNumber, 3)
        XCTAssertEqual(changes.first?.metadata.episodeNumber, 4)
    }

    func testStaleEpisodePointerMoveIsIgnored() {
        // The pointer moved, but to an episode that aired years ago — a
        // data correction, not news.
        let snapshot = makeSnapshot(mediaType: "tv", lastEpisodeID: 501)
        let fresh = ChangeClassifier.Fresh(
            details: makeDetails(lastEpisode: makeEpisode(id: 502, season: 1, episode: 9,
                                                          airDate: "2020-05-01"))
        )
        let changes = ChangeClassifier.changes(from: snapshot, fresh: fresh,
                                               hasReminder: false, now: fixedNow)
        XCTAssertTrue(changes.isEmpty)
    }

    func testNewSeasonIsDetected() {
        let snapshot = makeSnapshot(mediaType: "tv", seasonCount: 4)
        let fresh = ChangeClassifier.Fresh(details: makeDetails(seasons: 5))
        let changes = ChangeClassifier.changes(from: snapshot, fresh: fresh,
                                               hasReminder: false, now: fixedNow)
        XCTAssertEqual(changes.first?.kind, .newSeason)
        XCTAssertEqual(changes.first?.metadata.seasonNumber, 5)
    }

    func testEpisodeAirDateChangeIsDetected() {
        let snapshot = makeSnapshot(mediaType: "tv", nextEpisodeID: 600,
                                    nextEpisodeAirDate: "2026-09-01")
        let fresh = ChangeClassifier.Fresh(
            details: makeDetails(nextEpisode: makeEpisode(id: 600, season: 2, episode: 1,
                                                          airDate: "2026-09-12"))
        )
        let changes = ChangeClassifier.changes(from: snapshot, fresh: fresh,
                                               hasReminder: false, now: fixedNow)
        XCTAssertEqual(changes.first?.kind, .episodeDateChanged)
        XCTAssertEqual(changes.first?.metadata.airDate, "2026-09-12")
    }

    func testMovieReleaseIsDetected() {
        let snapshot = makeSnapshot(releaseDate: "2026-08-21", status: "Post Production")
        let fresh = ChangeClassifier.Fresh(details: makeDetails(releaseDate: "2026-08-21",
                                                                status: "Released"))
        let changes = ChangeClassifier.changes(from: snapshot, fresh: fresh,
                                               hasReminder: false, now: fixedNow)
        XCTAssertEqual(changes.first?.kind, .released)
    }

    func testSameTitleCollapsesToBestChange() {
        let changes = [
            makeChange(kind: .releaseDateChanged, id: 7),
            makeChange(kind: .newTrailer, id: 7),
            makeChange(kind: .released, id: 7)
        ]
        let ranked = ChangeClassifier.ranked(changes)
        XCTAssertEqual(ranked.count, 1)
        XCTAssertEqual(ranked.first?.kind, .newTrailer)
    }

    func testPriorityOrdering() {
        let ranked = ChangeClassifier.ranked([
            makeChange(kind: .released, id: 1),
            makeChange(kind: .newSeason, id: 2),
            makeChange(kind: .newTrailer, id: 3),
            makeChange(kind: .streamingAvailability, id: 4)
        ])
        XCTAssertEqual(ranked.map(\.kind), [.streamingAvailability, .newTrailer,
                                            .newSeason, .released])
    }

    func testReminderTitleRanksFirst() {
        let ranked = ChangeClassifier.ranked([
            makeChange(kind: .streamingAvailability, id: 1),
            makeChange(kind: .releaseDateChanged, id: 2, reminder: true)
        ])
        XCTAssertEqual(ranked.first?.mediaID, 2)
        XCTAssertTrue(ranked.first?.hasReminder ?? false)
    }

    func testShouldNotifyPolicy() {
        let trailer = makeChange(kind: .newTrailer)
        let dateShift = makeChange(kind: .releaseDateChanged)
        let remindedShift = makeChange(kind: .releaseDateChanged, reminder: true)

        XCTAssertTrue(WatchlistChangeMonitor.shouldNotify(trailer, lastNotifiedAt: nil, now: fixedNow))
        XCTAssertFalse(WatchlistChangeMonitor.shouldNotify(dateShift, lastNotifiedAt: nil, now: fixedNow))
        XCTAssertTrue(WatchlistChangeMonitor.shouldNotify(remindedShift, lastNotifiedAt: nil, now: fixedNow))
        // Cooldown throttles even high-value changes.
        XCTAssertFalse(WatchlistChangeMonitor.shouldNotify(
            trailer, lastNotifiedAt: fixedNow.addingTimeInterval(-3600), now: fixedNow))
    }
}

// MARK: - Store

@MainActor
final class WatchlistChangeStoreTests: XCTestCase {

    private func freshStore() { WatchlistChangeStore.reset() }

    func testSnapshotRoundtrip() {
        freshStore()
        let snapshot = makeSnapshot(mediaType: "tv", id: 42, seasonCount: 3)
        WatchlistChangeStore.save(snapshot)
        XCTAssertEqual(WatchlistChangeStore.snapshot(mediaType: "tv", mediaID: 42), snapshot)
        XCTAssertNil(WatchlistChangeStore.snapshot(mediaType: "movie", mediaID: 42))
    }

    func testAddAndFetchUnseen() {
        freshStore()
        let added = WatchlistChangeStore.add([makeChange(kind: .newTrailer, id: 1),
                                              makeChange(kind: .newSeason, id: 2)], now: fixedNow)
        XCTAssertEqual(added, 2)
        XCTAssertEqual(WatchlistChangeStore.unseenChanges(now: fixedNow).count, 2)
    }

    func testMarkSeenFiltersAndBlocksReAdd() {
        freshStore()
        let change = makeChange(kind: .newTrailer, id: 1)
        WatchlistChangeStore.add([change], now: fixedNow)
        WatchlistChangeStore.markSeen([change.id])

        XCTAssertTrue(WatchlistChangeStore.unseenChanges(now: fixedNow).isEmpty)
        // Re-detection of the identical change must be a no-op.
        XCTAssertEqual(WatchlistChangeStore.add([change], now: fixedNow), 0)
        XCTAssertTrue(WatchlistChangeStore.unseenChanges(now: fixedNow).isEmpty)
    }

    func testStaleChangesAreRejected() {
        freshStore()
        let stale = makeChange(kind: .newTrailer, id: 1,
                               occurredAt: fixedNow.addingTimeInterval(-40 * 24 * 3600))
        XCTAssertEqual(WatchlistChangeStore.add([stale], now: fixedNow), 0)
        XCTAssertTrue(WatchlistChangeStore.unseenChanges(now: fixedNow).isEmpty)
    }

    func testResetClearsEverything() {
        freshStore()
        WatchlistChangeStore.save(makeSnapshot())
        WatchlistChangeStore.add([makeChange(kind: .newTrailer)], now: fixedNow)
        WatchlistChangeStore.recordMeaningfulLaunch(now: fixedNow)

        WatchlistChangeStore.reset()

        XCTAssertEqual(WatchlistChangeStore.snapshotCount, 0)
        XCTAssertTrue(WatchlistChangeStore.unseenChanges(now: fixedNow).isEmpty)
        XCTAssertFalse(WatchlistChangeStore.wasAway(now: fixedNow))
    }

    func testAwayGate() {
        freshStore()
        // Never launched → not away (first-run baseline, never a briefing).
        XCTAssertFalse(WatchlistChangeStore.wasAway(now: fixedNow))

        // Opened an hour ago → not away.
        WatchlistChangeStore.recordMeaningfulLaunch(now: fixedNow.addingTimeInterval(-3600))
        XCTAssertFalse(WatchlistChangeStore.wasAway(now: fixedNow))

        // Opened 25 hours ago → away.
        WatchlistChangeStore.recordMeaningfulLaunch(now: fixedNow.addingTimeInterval(-25 * 3600))
        XCTAssertTrue(WatchlistChangeStore.wasAway(now: fixedNow))
    }
}

// MARK: - View model

@MainActor
final class WhatsNewViewModelTests: XCTestCase {

    private func freshVM() -> WhatsNewViewModel {
        WatchlistChangeStore.reset()
        return WhatsNewViewModel()
    }

    func testZeroChangesDoesNotPresent() {
        let vm = freshVM()
        XCTAssertFalse(vm.attemptPresentation(wasAway: true, now: fixedNow))
        XCTAssertFalse(vm.isPresented)
    }

    func testNotAwayDoesNotPresentDespiteChanges() {
        let vm = freshVM()
        WatchlistChangeStore.add([makeChange(kind: .newTrailer)], now: fixedNow)
        XCTAssertFalse(vm.attemptPresentation(wasAway: false, now: fixedNow))
    }

    func testSingleChangeUsesFocusedState() {
        let vm = freshVM()
        WatchlistChangeStore.add([makeChange(kind: .newTrailer)], now: fixedNow)

        XCTAssertTrue(vm.attemptPresentation(wasAway: true, now: fixedNow))
        XCTAssertTrue(vm.isSingleChange)
        XCTAssertEqual(vm.headline, "Something changed")
        XCTAssertNil(vm.overflowText)
    }

    func testBriefingCapsAtFiveAndReportsOverflow() {
        let vm = freshVM()
        let changes = (1...7).map { makeChange(kind: .newTrailer, id: $0, title: "Title \($0)") }
        WatchlistChangeStore.add(changes, now: fixedNow)

        XCTAssertTrue(vm.attemptPresentation(wasAway: true, now: fixedNow))
        XCTAssertEqual(vm.briefing.count, 5)
        XCTAssertEqual(vm.totalUnseenCount, 7)
        XCTAssertEqual(vm.overflowText, "Showing 5 of 7 updates")
        XCTAssertEqual(vm.headline, "While You Were Away")
    }

    func testBriefingIsRankedAndDeduplicated() {
        let vm = freshVM()
        WatchlistChangeStore.add([
            makeChange(kind: .released, id: 1),
            makeChange(kind: .streamingAvailability, id: 2),
            // Two changes on title 3 → one card, trailer wins.
            makeChange(kind: .newTrailer, id: 3),
            makeChange(kind: .newSeason, id: 3)
        ], now: fixedNow)

        XCTAssertTrue(vm.attemptPresentation(wasAway: true, now: fixedNow))
        XCTAssertEqual(vm.briefing.count, 3)
        XCTAssertEqual(vm.briefing.map(\.kind), [.streamingAvailability, .newTrailer, .released])
    }

    func testDismissalSpendsTheWholeBatch() {
        let vm = freshVM()
        let changes = (1...7).map { makeChange(kind: .newTrailer, id: $0) }
        WatchlistChangeStore.add(changes, now: fixedNow)

        XCTAssertTrue(vm.attemptPresentation(wasAway: true, now: fixedNow))
        vm.isPresented = false
        vm.briefingDismissed()

        // Everything — including the two overflow changes — is now seen.
        XCTAssertTrue(WatchlistChangeStore.unseenChanges(now: fixedNow).isEmpty)
        XCTAssertFalse(vm.attemptPresentation(wasAway: true, now: fixedNow))
    }

    /// The launch sync routinely lands while the sheet is still open. Those
    /// findings were never on screen, so dismissal must not retire them.
    func testDismissalKeepsChangesFiledAfterThePresentation() {
        let vm = freshVM()
        WatchlistChangeStore.add([makeChange(kind: .newTrailer, id: 1)], now: fixedNow)

        XCTAssertTrue(vm.attemptPresentation(wasAway: true, now: fixedNow))

        // Background sync lands a second change while the briefing is up.
        WatchlistChangeStore.add([makeChange(kind: .streamingAvailability, id: 2)], now: fixedNow)

        vm.isPresented = false
        vm.briefingDismissed()

        let survivors = WatchlistChangeStore.unseenChanges(now: fixedNow)
        XCTAssertEqual(survivors.map(\.mediaID), [2])
        // …and it leads the next briefing rather than being lost.
        XCTAssertTrue(vm.attemptPresentation(wasAway: true, now: fixedNow))
        XCTAssertEqual(vm.briefing.map(\.mediaID), [2])
    }

    /// A title collapsed out of the ranking (two changes, one card) is still
    /// part of the batch and must not resurface on its own.
    func testDismissalRetiresCollapsedSiblings() {
        let vm = freshVM()
        WatchlistChangeStore.add([
            makeChange(kind: .newTrailer, id: 1),
            makeChange(kind: .newSeason, id: 1)
        ], now: fixedNow)

        XCTAssertTrue(vm.attemptPresentation(wasAway: true, now: fixedNow))
        XCTAssertEqual(vm.briefing.count, 1)

        vm.isPresented = false
        vm.briefingDismissed()

        XCTAssertTrue(WatchlistChangeStore.unseenChanges(now: fixedNow).isEmpty)
    }
}

// MARK: - Regressions

/// Locks the behaviour fixed after the v1.6 review. Each of these describes
/// a bug that shipped in the branch, so they exist to stop it coming back
/// rather than to describe an intention.
@MainActor
final class WhatsNewRegressionTests: XCTestCase {

    /// Unsaving a title used to leave its change in the queue: the store
    /// pruned snapshots but not pending changes, so the next briefing led
    /// with a card that opened something the user had removed.
    func testPruningChangesDropsUnsavedTitles() {
        WatchlistChangeStore.reset()
        WatchlistChangeStore.add([
            makeChange(kind: .newTrailer, id: 1, mediaType: "movie"),
            makeChange(kind: .newEpisode, id: 2, mediaType: "tv")
        ], now: fixedNow)

        WatchlistChangeStore.pruneChanges(
            keeping: [WatchlistSnapshot.key(mediaType: "tv", mediaID: 2)])

        XCTAssertEqual(WatchlistChangeStore.unseenChanges(now: fixedNow).map(\.mediaID), [2])
    }

    /// Pruning keys on media type as well as id, so a movie and a series
    /// sharing a TMDB id don't take each other down.
    func testPruningDistinguishesMediaTypes() {
        WatchlistChangeStore.reset()
        WatchlistChangeStore.add([
            makeChange(kind: .newTrailer, id: 7, mediaType: "movie"),
            makeChange(kind: .newEpisode, id: 7, mediaType: "tv")
        ], now: fixedNow)

        WatchlistChangeStore.pruneChanges(
            keeping: [WatchlistSnapshot.key(mediaType: "movie", mediaID: 7)])

        let survivors = WatchlistChangeStore.unseenChanges(now: fixedNow)
        XCTAssertEqual(survivors.count, 1)
        XCTAssertEqual(survivors.first?.mediaType, "movie")
    }

    /// `isPresented = true` is a request UIKit can decline — when Movie
    /// Night's cover or another sheet already owns the scene. The briefing
    /// used to be stuck true for the rest of the session, unable to retry.
    /// Now it rolls back, and the changes stay owed.
    func testUnpresentedBriefingRollsBackAndKeepsItsChanges() async {
        WatchlistChangeStore.reset()
        let vm = WhatsNewViewModel()
        WatchlistChangeStore.add([makeChange(kind: .newTrailer)], now: fixedNow)

        XCTAssertTrue(vm.attemptPresentation(wasAway: true, now: fixedNow))
        XCTAssertTrue(vm.isPresented)

        // The sheet never reports appearing.
        try? await Task.sleep(for: .milliseconds(1600))

        XCTAssertFalse(vm.isPresented, "a presentation that never happened must not stay latched")
        XCTAssertFalse(WatchlistChangeStore.unseenChanges(now: fixedNow).isEmpty,
                       "changes the user never saw must stay unseen")
        // …and the next return can present them.
        XCTAssertTrue(vm.attemptPresentation(wasAway: true, now: fixedNow))
    }

    /// The counterpart: once the sheet says it appeared, the presentation
    /// stands and dismissal spends the batch as normal.
    func testAppearedBriefingIsNotRolledBack() async {
        WatchlistChangeStore.reset()
        let vm = WhatsNewViewModel()
        WatchlistChangeStore.add([makeChange(kind: .newTrailer)], now: fixedNow)

        XCTAssertTrue(vm.attemptPresentation(wasAway: true, now: fixedNow))
        vm.briefingDidAppear()

        try? await Task.sleep(for: .milliseconds(1600))
        XCTAssertTrue(vm.isPresented)

        vm.isPresented = false
        vm.briefingDismissed()
        XCTAssertTrue(WatchlistChangeStore.unseenChanges(now: fixedNow).isEmpty)
    }

    /// The sheet's content stays mounted for the length of the dismiss
    /// animation, so clearing the cards in `briefingDismissed` rewrote the
    /// header to "0 UPDATES" while it was still sliding away.
    func testDismissalLeavesCardsMountedForTheAnimation() {
        WatchlistChangeStore.reset()
        let vm = WhatsNewViewModel()
        WatchlistChangeStore.add([makeChange(kind: .newTrailer)], now: fixedNow)

        XCTAssertTrue(vm.attemptPresentation(wasAway: true, now: fixedNow))
        vm.briefingDidAppear()
        vm.isPresented = false
        vm.briefingDismissed()

        XCTAssertEqual(vm.briefing.count, 1)
        XCTAssertTrue(WatchlistChangeStore.unseenChanges(now: fixedNow).isEmpty,
                      "the batch is still spent — only the rendering survives")
    }
}

// MARK: - Result identity

/// `Result` declares `==` by hand, which does not stop the compiler
/// synthesizing `hash(into:)` over every stored property. The two
/// disagreed, and SwiftUI's `ForEach(…, id: \.self)` paid for it.
final class ResultIdentityTests: XCTestCase {

    private func result(id: Int?, title: String?, mediaType: String? = nil) -> Result {
        var value = Result.stub(id: id ?? 0, mediaType: mediaType ?? "movie")
        if id == nil || title != nil {
            value = Result(backdrop_path: nil, first_air_date: nil, genre_ids: nil,
                           id: id, original_title: nil, name: nil, origin_country: nil,
                           original_language: nil, original_name: nil, overview: nil,
                           popularity: nil, poster_path: nil, release_date: nil,
                           title: title, video: nil, vote_average: nil, vote_count: nil,
                           media_type: mediaType, profile_path: nil, castID: nil,
                           runtime: nil, known_for: nil)
        }
        return value
    }

    func testEqualValuesHashEqually() {
        let a = result(id: 42, title: "As decoded")
        let b = result(id: 42, title: "After an iCloud merge", mediaType: "movie")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testSetAndDictionaryAgreeOnIdentity() {
        let a = result(id: 42, title: "One")
        let b = result(id: 42, title: "Two")

        // Before the fix these landed in different buckets: the set kept two
        // entries while the dictionary kept one, from the same pair of
        // values.
        XCTAssertEqual(Set([a, b]).count, 1)

        // Built by subscript, not a literal — a dictionary literal with two
        // keys that are `==` traps rather than failing an assertion.
        var byResult: [Result: Int] = [:]
        byResult[a] = 1
        byResult[b] = 2
        XCTAssertEqual(byResult.count, 1)
        XCTAssertEqual(byResult[a], 2, "the second write must find the first key")
    }

    func testDifferentIdsStayDistinct() {
        let a = result(id: 1, title: "A")
        let b = result(id: 2, title: "A")
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(Set([a, b]).count, 2)
    }
}

// MARK: - Inferred media type

/// Saved titles from builds that didn't stamp `media_type` must not be
/// mistaken for people: `getMediaType()` answers "Actor" for them, which
/// put a person glyph on films in the poster wall and routed watchlist rows
/// into the actor UI, where they had no way to be removed.
final class InferredMediaTypeTests: XCTestCase {

    private func untagged(name: String?, title: String?) -> Result {
        Result(backdrop_path: nil, first_air_date: nil, genre_ids: nil, id: 1,
               original_title: nil, name: name, origin_country: nil,
               original_language: nil, original_name: nil, overview: nil,
               popularity: nil, poster_path: nil, release_date: nil, title: title,
               video: nil, vote_average: nil, vote_count: nil, media_type: nil,
               profile_path: nil, castID: nil, runtime: nil, known_for: nil)
    }

    func testUntaggedSeriesInfersTV() {
        XCTAssertEqual(untagged(name: "Severance", title: nil).inferredScreenType, .tv)
    }

    func testUntaggedFilmInfersMovie() {
        XCTAssertEqual(untagged(name: nil, title: "Dune").inferredScreenType, .movie)
    }

    func testUntaggedTitleIsNotAPerson() {
        XCTAssertFalse(untagged(name: "Severance", title: nil).isPerson)
        XCTAssertFalse(untagged(name: nil, title: "Dune").isPerson)
    }

    func testTaggedPersonIsAPerson() {
        XCTAssertTrue(Result.stub(id: 5, mediaType: "person").isPerson)
    }
}

// MARK: - Fetch-failure contract

/// The monitor must express "this domain could not be fetched" as nil, never
/// as an empty array. These lock the classifier behaviour that depends on it.
@MainActor
final class FetchFailureContractTests: XCTestCase {

    func testNilVideosDomainPreservesKnownTrailers() {
        let snapshot = makeSnapshot(videoIDs: ["a", "b"])
        let next = ChangeClassifier.updatedSnapshot(snapshot,
                                                    fresh: ChangeClassifier.Fresh(videos: nil),
                                                    now: fixedNow)
        // A failed request must never wipe state — otherwise the next
        // successful fetch reports every existing trailer as brand new.
        XCTAssertEqual(next.videoIDs, ["a", "b"])
    }

    func testEmptyVideosDomainIsARealStateAndClearsThem() {
        let snapshot = makeSnapshot(videoIDs: ["a", "b"])
        let next = ChangeClassifier.updatedSnapshot(snapshot,
                                                    fresh: ChangeClassifier.Fresh(videos: []),
                                                    now: fixedNow)
        XCTAssertEqual(next.videoIDs, [])
    }

    func testNilVideosDomainProducesNoTrailerChange() {
        let snapshot = makeSnapshot(videoIDs: [])
        let changes = ChangeClassifier.changes(from: snapshot,
                                               fresh: ChangeClassifier.Fresh(videos: nil),
                                               hasReminder: false,
                                               now: fixedNow)
        XCTAssertTrue(changes.isEmpty)
    }
}
