//
//  OnboardingTests.swift
//  WatchnowTests
//
//  The gate, the seeder, and the provider curation.
//
//  The gate gets the most attention because its worst failure is invisible
//  in testing and unforgivable in the wild: showing a three-step setup flow
//  to someone who has been using the app for a year and just reinstalled.
//  That case only happens when iCloud is slow, which is exactly when nobody
//  is looking.
//

import XCTest
@testable import Watchnow

// MARK: - OnboardingGate

final class OnboardingGateTests: XCTestCase {

    private func inputs(completed: Bool = false,
                        watchlist: Int = 0,
                        cloud: Bool = true,
                        merged: Bool = false,
                        waited: TimeInterval = 0) -> OnboardingGate.Inputs {
        OnboardingGate.Inputs(hasCompletedOnboarding: completed,
                              watchlistCount: watchlist,
                              isCloudAvailable: cloud,
                              didMergeWatchlist: merged,
                              waited: waited)
    }

    func testAFreshInstallWithoutICloudGoesStraightIn() {
        // Nothing can arrive, so waiting would only stall a real new user.
        XCTAssertEqual(OnboardingGate.decide(inputs(cloud: false)), .show)
    }

    func testAFreshInstallWithICloudWaitsFirst() {
        XCTAssertEqual(OnboardingGate.decide(inputs()), .wait)
    }

    func testWaitingEndsAtTheTimeout() {
        XCTAssertEqual(OnboardingGate.decide(inputs(waited: OnboardingGate.restoreTimeout - 0.1)), .wait)
        XCTAssertEqual(OnboardingGate.decide(inputs(waited: OnboardingGate.restoreTimeout)), .show)
    }

    func testAMergeThatBroughtNothingEndsTheWaitEarly() {
        // iCloud has spoken and had nothing, so sitting out the rest of the
        // timeout would be three seconds of nothing for a real new user.
        XCTAssertEqual(OnboardingGate.decide(inputs(merged: true, waited: 0.2)), .show)
    }

    func testARestoredWatchlistSkipsOnboardingEntirely() {
        // The case this whole gate exists for: a year-old watchlist landing
        // half a second after launch must never see a setup flow.
        XCTAssertEqual(OnboardingGate.decide(inputs(watchlist: 47, merged: true, waited: 0.5)), .skip)
    }

    func testDataPresentBeforeTheWaitEvenStartsSkips() {
        XCTAssertEqual(OnboardingGate.decide(inputs(watchlist: 1)), .skip)
    }

    func testHavingDoneItBeforeAlwaysSkips() {
        // The flag syncs, so this covers the second device too.
        XCTAssertEqual(OnboardingGate.decide(inputs(completed: true)), .skip)
        XCTAssertEqual(OnboardingGate.decide(inputs(completed: true, cloud: false)), .skip)
        XCTAssertEqual(OnboardingGate.decide(inputs(completed: true, watchlist: 12)), .skip)
    }

    func testCompletionOutranksAnEmptyWatchlist() {
        // Someone who skipped every step has an empty watchlist and has
        // still been onboarded. Asking again would be the app refusing to
        // hear "no thanks".
        XCTAssertEqual(OnboardingGate.decide(inputs(completed: true, watchlist: 0, waited: 99)), .skip)
    }
}

// MARK: - TasteSeeder

final class TasteSeederTests: XCTestCase {

    /// `Result`'s identity fields are `let`, so a fixture builds the whole
    /// thing rather than mutating a stub.
    private func pick(_ id: Int?, genres: [Int]? = [18, 35], language: String? = "en") -> Result {
        Result(backdrop_path: nil, first_air_date: nil, genre_ids: genres, id: id,
               original_title: nil, name: nil, origin_country: nil,
               original_language: language, original_name: nil, overview: nil,
               popularity: nil, poster_path: nil, release_date: nil, title: "Fixture",
               video: nil, vote_average: nil, vote_count: nil, media_type: "movie",
               profile_path: nil, castID: nil, runtime: nil, known_for: nil)
    }

    func testEachPickBecomesOneSignal() {
        let signals = TasteSeeder.signals(from: [pick(1), pick(2)])
        XCTAssertEqual(signals.map(\.id), [1, 2])
        XCTAssertEqual(signals[0].genreIDs, [18, 35])
        XCTAssertEqual(signals[0].language, "en")
    }

    func testOrderIsPreserved() {
        // The first pick is the one the finish screen asks Coach about.
        XCTAssertEqual(TasteSeeder.signals(from: [pick(9), pick(3), pick(5)]).map(\.id), [9, 3, 5])
    }

    func testDuplicatesCollapse() {
        // A double tap must not weight a genre twice.
        XCTAssertEqual(TasteSeeder.signals(from: [pick(1), pick(1)]).map(\.id), [1])
    }

    func testPicksWithoutAnIDAreDropped() {
        XCTAssertTrue(TasteSeeder.signals(from: [pick(nil)]).isEmpty)
    }

    func testMissingGenresBecomeAnEmptyListNotAFailure() {
        let signals = TasteSeeder.signals(from: [pick(1, genres: nil, language: nil)])
        XCTAssertEqual(signals.count, 1)
        XCTAssertTrue(signals[0].genreIDs.isEmpty)
        XCTAssertNil(signals[0].language)
    }
}

// MARK: - Provider curation

final class StreamingProviderCatalogTests: XCTestCase {

    private func provider(_ id: Int, _ name: String, priority: Int? = nil) -> WatchProvider {
        WatchProvider(provider_id: id, provider_name: name,
                      logo_path: nil, display_priority: priority)
    }

    func testOnlyCuratedSubscriptionServicesSurvive() {
        // TMDB's list mixes rent/buy storefronts and ad tiers in with the
        // subscriptions people mean by "what I have".
        let curated = StreamingProviderCatalog.curated(from: [
            provider(8, "Netflix"),
            provider(2, "Apple TV Store"),      // rent/buy — not a subscription
            provider(99_999, "Some Niche Thing")
        ])
        XCTAssertEqual(curated.map(\.provider_name), ["Netflix"])
    }

    func testOrderFollowsTheCuratedListNotTMDBPriority() {
        // TMDB's own display_priority ranks regional services above
        // household names in some regions; ours does not.
        let curated = StreamingProviderCatalog.curated(from: [
            provider(309, "Sun Nxt", priority: 0),
            provider(15, "Hulu", priority: 90),
            provider(8, "Netflix", priority: 50)
        ])
        XCTAssertEqual(curated.map(\.provider_name), ["Netflix", "Hulu", "Sun Nxt"])
    }

    func testAppleTVPlusIsIncludedAndTheAppleStoreIsNot() {
        XCTAssertTrue(StreamingProviderCatalog.subscriptionProviders.contains(350))
        XCTAssertFalse(StreamingProviderCatalog.subscriptionProviders.contains(2))
    }

    func testNoProvidersIsAnEmptyListNotACrash() {
        XCTAssertTrue(StreamingProviderCatalog.curated(from: nil).isEmpty)
        XCTAssertTrue(StreamingProviderCatalog.curated(from: []).isEmpty)
    }
}

// MARK: - Onboarding state & Coach counting

@MainActor
final class OnboardingStateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        OnboardingState.reset()
    }

    func testItStartsIncomplete() {
        XCTAssertFalse(OnboardingState.hasCompleted)
    }

    func testMarkingIsIdempotent() {
        OnboardingState.markCompleted()
        OnboardingState.markCompleted()
        XCTAssertTrue(OnboardingState.hasCompleted)
    }

    func testCompletionSyncs() {
        // Someone who set up on their phone should not be asked again on
        // their iPad, even before the watchlist itself arrives.
        XCTAssertTrue(CloudSync.syncedKeys.contains("hasCompletedOnboarding"))
    }

    func testInterleavingMixesBothMediaTypes() {
        // A block of films followed by a block of shows reads as "films",
        // and the step is asking about both.
        let movies = (1...5).map { Result.stub(id: $0, mediaType: "movie") }
        let series = (101...105).map { Result.stub(id: $0, mediaType: "tv") }
        let mixed = OnboardingViewModel.interleaved(movies: movies, series: series, limit: 6)
        XCTAssertEqual(mixed.map(\.id), [1, 101, 2, 102, 3, 103])
    }

    func testInterleavingSurvivesAnEmptySide() {
        let movies = (1...3).map { Result.stub(id: $0, mediaType: "movie") }
        XCTAssertEqual(OnboardingViewModel.interleaved(movies: movies, series: [], limit: 10).map(\.id),
                       [1, 2, 3])
        XCTAssertTrue(OnboardingViewModel.interleaved(movies: [], series: [], limit: 10).isEmpty)
    }
}
