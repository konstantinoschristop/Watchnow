//
//  AlertsTests.swift
//  WatchnowTests
//
//  Unit coverage for the automatic-alerts foundation: the pure decision in
//  `AutoAlertPolicy`, the persisted exceptions in `AlertPreferences`, and
//  the two assumptions they quietly rest on — that `@UserDefault` can carry
//  a `Bool`, and that the right keys (and only the right keys) sync.
//
//  Same shape as `WhatsNewTests`: no network, hand-built values, and the
//  store wiped against the test host's `UserDefaults` before every test.
//

import XCTest
@testable import Watchnow

// MARK: - AutoAlertPolicy

final class AutoAlertPolicyTests: XCTestCase {

    private func inputs(saved: Bool = true,
                        episodes: Bool = true,
                        streaming: Bool = true,
                        muted: Bool = false) -> AutoAlertPolicy.Inputs {
        AutoAlertPolicy.Inputs(isSaved: saved,
                               episodeAlertsEnabled: episodes,
                               streamingAlertsEnabled: streaming,
                               isOptedOut: muted)
    }

    func testSavedTitleGetsBothKindsByDefault() {
        XCTAssertEqual(AutoAlertPolicy.alertKinds(for: inputs()), [.episode, .streaming])
        XCTAssertTrue(AutoAlertPolicy.isFollowed(inputs()))
    }

    func testUnsavedTitleGetsNothing() {
        // Nothing subscribes except a save. A title merely looked at, liked,
        // or swiped past in Movie Night must never produce an alert.
        XCTAssertTrue(AutoAlertPolicy.alertKinds(for: inputs(saved: false)).isEmpty)
        XCTAssertFalse(AutoAlertPolicy.isFollowed(inputs(saved: false)))
    }

    func testMutedTitleGetsNothingEvenWithBothSwitchesOn() {
        XCTAssertTrue(AutoAlertPolicy.alertKinds(for: inputs(muted: true)).isEmpty)
    }

    func testGlobalSwitchesNarrowTheKinds() {
        XCTAssertEqual(AutoAlertPolicy.alertKinds(for: inputs(streaming: false)), [.episode])
        XCTAssertEqual(AutoAlertPolicy.alertKinds(for: inputs(episodes: false)), [.streaming])
    }

    func testBothSwitchesOffIsSilence() {
        let off = inputs(episodes: false, streaming: false)
        XCTAssertTrue(AutoAlertPolicy.alertKinds(for: off).isEmpty)
        // The bell must not claim an alert that will never be sent.
        XCTAssertFalse(AutoAlertPolicy.isFollowed(off))
    }

    func testMutingBeatsEverySwitchCombination() {
        for episodes in [true, false] {
            for streaming in [true, false] {
                let muted = inputs(episodes: episodes, streaming: streaming, muted: true)
                XCTAssertTrue(AutoAlertPolicy.alertKinds(for: muted).isEmpty,
                              "muted should win for episodes=\(episodes) streaming=\(streaming)")
            }
        }
    }
}

// MARK: - AlertPreferences

@MainActor
final class AlertPreferencesTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AlertPreferences.reset()
    }

    func testDefaultsAreBothOn() {
        // A release whose whole point is bringing people back cannot ship
        // with its return triggers off by default.
        XCTAssertTrue(AlertPreferences.episodeAlertsEnabled)
        XCTAssertTrue(AlertPreferences.streamingAlertsEnabled)
    }

    func testBoolSurvivesTheUserDefaultWrapper() {
        // `@UserDefault` JSON-encodes everything, and a bare `Bool` is a
        // top-level JSON fragment. The two switches above are the app's
        // first Bools to go through it, so prove the round trip rather than
        // assume it.
        AlertPreferences.episodeAlertsEnabled = false
        XCTAssertFalse(AlertPreferences.episodeAlertsEnabled)
        AlertPreferences.episodeAlertsEnabled = true
        XCTAssertTrue(AlertPreferences.episodeAlertsEnabled)
    }

    func testTitleIsUnmutedUntilSaidOtherwise() {
        XCTAssertFalse(AlertPreferences.isOptedOut(550))
    }

    func testMuteRoundTrip() {
        AlertPreferences.setOptedOut(true, for: 550)
        XCTAssertTrue(AlertPreferences.isOptedOut(550))
        XCTAssertFalse(AlertPreferences.isOptedOut(551))

        AlertPreferences.setOptedOut(false, for: 550)
        XCTAssertFalse(AlertPreferences.isOptedOut(550))
    }

    func testMutingTwiceStoresOneException() {
        AlertPreferences.setOptedOut(true, for: 550)
        AlertPreferences.setOptedOut(true, for: 550)
        AlertPreferences.setOptedOut(false, for: 550)
        // One unmute must be enough — a duplicated id would survive it.
        XCTAssertFalse(AlertPreferences.isOptedOut(550))
    }

    func testForgetClearsTheException() {
        // Unsaving forgets the mute, so re-saving later starts from the
        // default rather than from a decision about a different moment.
        AlertPreferences.setOptedOut(true, for: 550)
        AlertPreferences.forget(resultID: 550)
        XCTAssertFalse(AlertPreferences.isOptedOut(550))
    }

    func testPolicyInputsReflectTheStore() {
        AlertPreferences.streamingAlertsEnabled = false
        AlertPreferences.setOptedOut(true, for: 42)

        let muted = AlertPreferences.policyInputs(forID: 42, isSaved: true)
        XCTAssertTrue(muted.isSaved)
        XCTAssertTrue(muted.episodeAlertsEnabled)
        XCTAssertFalse(muted.streamingAlertsEnabled)
        XCTAssertTrue(muted.isOptedOut)

        let other = AlertPreferences.policyInputs(forID: 43, isSaved: false)
        XCTAssertFalse(other.isSaved)
        XCTAssertFalse(other.isOptedOut)
    }

    func testAlertKeysSyncButThePermissionFlagDoesNot() {
        // A title muted on the phone should stay muted on the iPad; the
        // device's notification permission is iOS's business, per device.
        XCTAssertTrue(CloudSync.syncedKeys.contains("alertsEpisodesEnabled"))
        XCTAssertTrue(CloudSync.syncedKeys.contains("alertsStreamingEnabled"))
        XCTAssertTrue(CloudSync.syncedKeys.contains("alertsOptedOutIDs"))
        XCTAssertFalse(CloudSync.syncedKeys.contains("alertsDidShowPermissionExplainer"))
    }

    func testResetRestoresDefaults() {
        AlertPreferences.episodeAlertsEnabled = false
        AlertPreferences.streamingAlertsEnabled = false
        AlertPreferences.setOptedOut(true, for: 550)
        AlertPreferences.didShowPermissionExplainer = true

        AlertPreferences.reset()

        XCTAssertTrue(AlertPreferences.episodeAlertsEnabled)
        XCTAssertTrue(AlertPreferences.streamingAlertsEnabled)
        XCTAssertFalse(AlertPreferences.isOptedOut(550))
        XCTAssertFalse(AlertPreferences.didShowPermissionExplainer)
    }
}
