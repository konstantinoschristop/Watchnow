//
//  ReviewPromptTests.swift
//  WatchnowTests
//
//  iOS allows three review prompts a year and tells you nothing about why
//  you spent them. Every gate in `ReviewPromptPolicy` exists to stop one
//  being wasted, and none of them can be observed by using the app — the
//  throttle alone would take four months to test by hand.
//

import XCTest
@testable import Watchnow

private let now = Date(timeIntervalSince1970: 1_789_000_000)
private let day: TimeInterval = 86_400

private func inputs(_ trigger: ReviewTrigger = .movieNightMatch,
                    installedDaysAgo: Double? = 30,
                    promptedDaysAgo: Double? = nil,
                    firstSession: Bool = false,
                    saved: Int = 0,
                    watched: Int = 0) -> ReviewPromptPolicy.Inputs {
    ReviewPromptPolicy.Inputs(
        trigger: trigger,
        firstLaunchedAt: installedDaysAgo.map { now.addingTimeInterval(-$0 * day) },
        lastPromptedAt: promptedDaysAgo.map { now.addingTimeInterval(-$0 * day) },
        isFirstSession: firstSession,
        savedCount: saved,
        watchedCount: watched,
        now: now)
}

final class ReviewPromptPolicyTests: XCTestCase {

    // MARK: Timing

    func testNeverInTheFirstSession() {
        // Belt and braces with the settling period below: this still holds
        // when the device clock is wrong or the install date is missing.
        XCTAssertFalse(ReviewPromptPolicy.shouldAsk(inputs(firstSession: true)))
    }

    func testNeverInTheFirstFortyEightHours() {
        XCTAssertFalse(ReviewPromptPolicy.shouldAsk(inputs(installedDaysAgo: 0.5)))
        XCTAssertFalse(ReviewPromptPolicy.shouldAsk(inputs(installedDaysAgo: 1.99)))
        XCTAssertTrue(ReviewPromptPolicy.shouldAsk(inputs(installedDaysAgo: 2)))
    }

    func testAnUnknownInstallDateMeansDoNotAsk() {
        // An install predating this bookkeeping. "Don't know" must not be
        // read as "long ago".
        XCTAssertFalse(ReviewPromptPolicy.shouldAsk(inputs(installedDaysAgo: nil)))
    }

    // MARK: Throttle

    func testAtMostOnceEveryFourMonths() {
        XCTAssertFalse(ReviewPromptPolicy.shouldAsk(inputs(promptedDaysAgo: 1)))
        XCTAssertFalse(ReviewPromptPolicy.shouldAsk(inputs(promptedDaysAgo: 119)))
        XCTAssertTrue(ReviewPromptPolicy.shouldAsk(inputs(promptedDaysAgo: 120)))
    }

    func testNeverHavingAskedIsNotAThrottle() {
        XCTAssertTrue(ReviewPromptPolicy.shouldAsk(inputs(promptedDaysAgo: nil)))
    }

    func testTheThrottleOutranksEveryTrigger() {
        for trigger in ReviewTrigger.allCases {
            XCTAssertFalse(ReviewPromptPolicy.shouldAsk(
                inputs(trigger, promptedDaysAgo: 10, saved: 99, watched: 99)),
                "\(trigger) should not beat the throttle")
        }
    }

    // MARK: Triggers

    func testAMatchNeedsNoThreshold() {
        // The payoff of a whole session the user chose to play.
        XCTAssertTrue(ReviewPromptPolicy.shouldAsk(inputs(.movieNightMatch, saved: 0, watched: 0)))
    }

    func testMarkingWatchedQualifiesOnTheThird() {
        XCTAssertFalse(ReviewPromptPolicy.shouldAsk(inputs(.markedWatched, watched: 2)))
        XCTAssertTrue(ReviewPromptPolicy.shouldAsk(inputs(.markedWatched, watched: 3)))
    }

    func testSavingQualifiesOnTheThird() {
        // Kept from v2.0 alongside the two new triggers: the store has no
        // ratings, and narrowing the funnel is the wrong fix for that.
        XCTAssertFalse(ReviewPromptPolicy.shouldAsk(inputs(.savedTitle, saved: 2)))
        XCTAssertTrue(ReviewPromptPolicy.shouldAsk(inputs(.savedTitle, saved: 3)))
    }

    func testCountsDoNotLeakBetweenTriggers() {
        // Three saves must not make a watched trigger qualify, or the
        // thresholds mean nothing.
        XCTAssertFalse(ReviewPromptPolicy.shouldAsk(inputs(.markedWatched, saved: 9, watched: 0)))
        XCTAssertFalse(ReviewPromptPolicy.shouldAsk(inputs(.savedTitle, saved: 0, watched: 9)))
    }

    func testEveryTriggerStillObeysTheSettlingPeriod() {
        for trigger in ReviewTrigger.allCases {
            XCTAssertFalse(ReviewPromptPolicy.shouldAsk(
                inputs(trigger, installedDaysAgo: 1, saved: 99, watched: 99)),
                "\(trigger) should not beat the settling period")
        }
    }
}

// MARK: - Manager bookkeeping

@MainActor
final class ReviewRequestManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ReviewRequestManager.reset()
    }

    override func tearDown() {
        ReviewRequestManager.reset()
        super.tearDown()
    }

    func testTheFirstLaunchRecordsAnInstallDate() {
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        ReviewRequestManager.recordLaunch(now: at)
        XCTAssertEqual(UserDefaults.standard.object(forKey: "review.firstSeenDate") as? Date, at)
    }

    func testALaterLaunchDoesNotMoveTheInstallDate() {
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        ReviewRequestManager.recordLaunch(now: first)
        ReviewRequestManager.recordLaunch(now: first.addingTimeInterval(90 * 86_400))
        XCTAssertEqual(UserDefaults.standard.object(forKey: "review.firstSeenDate") as? Date, first)
    }

    func testSavesAreCounted() {
        ReviewRequestManager.recordWatchlistAdd()
        ReviewRequestManager.recordWatchlistAdd()
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "review.qualifyingActionCount"), 2)
    }

    func testUpgradingFromTheVersionMarkerStartsTheClockNow() {
        // v2.0 recorded only *which version* last prompted. An upgrading
        // user carries no date, and asking again immediately is the one
        // outcome worth ruling out.
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        UserDefaults.standard.set(version, forKey: "review.lastPromptedVersion")

        let at = Date(timeIntervalSince1970: 1_789_000_000)
        ReviewRequestManager.recordLaunch(now: at)

        XCTAssertEqual(UserDefaults.standard.object(forKey: "review.lastPromptedAt") as? Date, at)
        XCTAssertNil(UserDefaults.standard.string(forKey: "review.lastPromptedVersion"))
    }

    func testAMarkerFromAnOlderVersionDoesNotThrottle() {
        UserDefaults.standard.set("1.9", forKey: "review.lastPromptedVersion")
        ReviewRequestManager.recordLaunch(now: Date())
        XCTAssertNil(UserDefaults.standard.object(forKey: "review.lastPromptedAt"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "review.lastPromptedVersion"))
    }
}
