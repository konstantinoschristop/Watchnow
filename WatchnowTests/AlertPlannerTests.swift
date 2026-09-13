//
//  AlertPlannerTests.swift
//  WatchnowTests
//
//  The restraint rules, proved. Everything the user experiences as "this app
//  doesn't spam me" is a line in `AlertPlanner`, and none of it is observable
//  by running the app — the soonest real episode might be nine days out. So
//  it is all pinned here instead: the caps, the quiet hours, iOS's 64-request
//  ceiling, and the rule that a reminder set by hand always wins.
//
//  Dates run in a fixed non-UTC calendar on purpose. TMDB air dates are
//  date-only and parsed as UTC midnight, and the planner has to turn those
//  into 18:00 *local*; testing in UTC would let a timezone bug through
//  unnoticed.
//

import XCTest
@testable import Watchnow

// MARK: - Fixtures

private let zone = TimeZone(identifier: "America/New_York")!

private let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}()

/// "2026-10-01" as TMDB delivers it: UTC midnight.
private func airDay(_ raw: String) -> Date {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: raw)!
}

/// "2026-10-01 18:00" in the test's local zone.
private func localTime(_ raw: String) -> Date {
    let formatter = DateFormatter()
    formatter.calendar = testCalendar
    formatter.timeZone = zone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.date(from: raw)!
}

private let now = localTime("2026-09-30 12:00")

private func episode(_ mediaID: Int,
                     title: String = "Fixture Show",
                     on day: String,
                     episodeID: Int? = nil,
                     season: Int? = 3,
                     number: Int? = 7,
                     savedAt: Date? = nil) -> EpisodeEvent {
    EpisodeEvent(mediaID: mediaID,
                 seriesTitle: title,
                 episodeID: episodeID,
                 seasonNumber: season,
                 episodeNumber: number,
                 airDate: airDay(day),
                 savedAt: savedAt)
}

private func streaming(_ mediaID: Int,
                      title: String = "Fixture Film",
                      service: String? = "Netflix",
                      mediaType: String = "movie",
                      savedAt: Date? = nil) -> StreamingChange {
    StreamingChange(changeID: "movie.\(mediaID).streamingAvailability.8",
                    mediaID: mediaID,
                    mediaType: mediaType,
                    title: title,
                    serviceName: service,
                    savedAt: savedAt)
}

private func plan(_ episodes: [EpisodeEvent],
                  streamingChanges: [StreamingChange] = [],
                  manual: [ManualReminder] = [],
                  at instant: Date = now) -> [PlannedAlert] {
    AlertPlanner.plan(episodes: episodes,
                      streamingChanges: streamingChanges,
                      manualReminders: manual,
                      now: instant,
                      calendar: testCalendar)
}

// MARK: - Timing

final class AlertPlannerTimingTests: XCTestCase {

    func testEpisodeFiresAtSixPmLocalOnTheAirDate() {
        let result = plan([episode(1, on: "2026-10-01")])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].fireDate, localTime("2026-10-01 18:00"))
    }

    func testAirDateIsReadInUTCAndRebuiltLocally() {
        // The bug this guards: treating TMDB's UTC-midnight date as a local
        // instant puts a New York user's Thursday episode on Wednesday.
        let result = plan([episode(1, on: "2026-10-01")])
        let components = testCalendar.dateComponents([.year, .month, .day, .hour],
                                                     from: result[0].fireDate)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.month, 10)
        XCTAssertEqual(components.hour, 18)
    }

    func testAlreadyPastEpisodesAreNotPlanned() {
        XCTAssertTrue(plan([episode(1, on: "2026-09-20")]).isEmpty)
    }

    func testTodaysEpisodeIsStillPlannedWhenSixPmHasNotArrived() {
        // `now` is noon; 18:00 today is still ahead.
        XCTAssertEqual(plan([episode(1, on: "2026-09-30")]).count, 1)
    }

    func testNothingInMakesNothingOut() {
        XCTAssertTrue(plan([]).isEmpty)
    }

    func testPlanIsOrderedByFireDate() {
        let result = plan([episode(3, on: "2026-10-05"),
                           episode(1, on: "2026-10-01"),
                           episode(2, on: "2026-10-03")])
        XCTAssertEqual(result.map(\.fireDate), result.map(\.fireDate).sorted())
    }

    func testPlanningTwiceGivesTheIdenticalResult() {
        // Reconciling depends on this: a plan that reshuffles itself would
        // churn the schedule on every launch.
        let episodes = [episode(1, on: "2026-10-01"), episode(2, on: "2026-10-01")]
        XCTAssertEqual(plan(episodes), plan(episodes))
    }
}

// MARK: - Quiet hours

final class AlertPlannerQuietHoursTests: XCTestCase {

    private func moved(_ raw: String) -> Date {
        AlertPlanner.movedOutOfQuietHours(localTime(raw), calendar: testCalendar)
    }

    func testSixPmIsLeftAlone() {
        XCTAssertEqual(moved("2026-10-01 18:00"), localTime("2026-10-01 18:00"))
    }

    func testLastMinuteBeforeQuietHoursIsLeftAlone() {
        XCTAssertEqual(moved("2026-10-01 21:59"), localTime("2026-10-01 21:59"))
    }

    func testLateEveningRollsToNextMorning() {
        XCTAssertEqual(moved("2026-10-01 22:00"), localTime("2026-10-02 09:00"))
        XCTAssertEqual(moved("2026-10-01 23:30"), localTime("2026-10-02 09:00"))
    }

    func testSmallHoursMoveToTheSameMorning() {
        XCTAssertEqual(moved("2026-10-01 03:00"), localTime("2026-10-01 09:00"))
        XCTAssertEqual(moved("2026-10-01 00:01"), localTime("2026-10-01 09:00"))
    }

    func testNineAmIsTheFirstAllowedMoment() {
        XCTAssertEqual(moved("2026-10-01 09:00"), localTime("2026-10-01 09:00"))
        XCTAssertEqual(moved("2026-10-01 08:59"), localTime("2026-10-01 09:00"))
    }
}

// MARK: - Caps

final class AlertPlannerCapTests: XCTestCase {

    func testOneAlertPerTitlePerDay() {
        // A show dropping a whole season at once is still one notification.
        let result = plan([episode(1, on: "2026-10-01", episodeID: 11, number: 1),
                           episode(1, on: "2026-10-01", episodeID: 12, number: 2),
                           episode(1, on: "2026-10-01", episodeID: 13, number: 3)])
        XCTAssertEqual(result.count, 1)
    }

    func testSameTitleOnDifferentDaysIsAllowed() {
        let result = plan([episode(1, on: "2026-10-01"), episode(1, on: "2026-10-08")])
        XCTAssertEqual(result.count, 2)
    }

    func testAtMostThreeADay() {
        let result = plan((1...6).map { episode($0, on: "2026-10-01") })
        XCTAssertEqual(result.count, AlertPlanner.maxPerDay)
    }

    func testManualRemindersOccupyTheDailyAllowanceFirst() {
        // Two of the day's three slots are already the user's own; only one
        // inferred alert may join them.
        let manual = [
            ManualReminder(identifier: "reminder.title.900",
                           fireDate: localTime("2026-10-01 09:00"), mediaID: 900),
            ManualReminder(identifier: "reminder.title.901",
                           fireDate: localTime("2026-10-01 09:00"), mediaID: 901)
        ]
        let result = plan((1...5).map { episode($0, on: "2026-10-01") }, manual: manual)
        XCTAssertEqual(result.count, 1)
    }

    func testDailyAllowanceCanBeFullyConsumedByManualReminders() {
        let manual = (900...902).map {
            ManualReminder(identifier: "reminder.title.\($0)",
                           fireDate: localTime("2026-10-01 09:00"), mediaID: $0)
        }
        XCTAssertTrue(plan((1...5).map { episode($0, on: "2026-10-01") }, manual: manual).isEmpty)
    }

    func testNeverExceedsSixtyFourPendingRequests() {
        // 90 candidates, three a day across thirty days — the per-day cap
        // allows them all, so the 64 ceiling is what has to bite.
        var episodes: [EpisodeEvent] = []
        for dayOffset in 1...30 {
            let day = String(format: "2026-10-%02d", dayOffset)
            for slot in 0..<3 { episodes.append(episode(dayOffset * 10 + slot, on: day)) }
        }
        XCTAssertEqual(episodes.count, 90)
        XCTAssertEqual(plan(episodes).count, AlertPlanner.maxPending)
    }

    func testManualRemindersCountTowardTheSixtyFour() {
        var episodes: [EpisodeEvent] = []
        for dayOffset in 1...30 {
            let day = String(format: "2026-10-%02d", dayOffset)
            for slot in 0..<3 { episodes.append(episode(dayOffset * 10 + slot, on: day)) }
        }
        // Parked in December so they take global budget without touching any
        // candidate's day allowance.
        let manual = (900...909).map {
            ManualReminder(identifier: "reminder.title.\($0)",
                           fireDate: localTime("2026-12-0\(($0 - 900) % 9 + 1) 09:00"),
                           mediaID: $0)
        }
        XCTAssertEqual(plan(episodes, manual: manual).count, AlertPlanner.maxPending - 10)
    }

    func testTheSurvivorsAreTheSoonestOnes() {
        var episodes: [EpisodeEvent] = []
        for dayOffset in 1...30 {
            let day = String(format: "2026-10-%02d", dayOffset)
            for slot in 0..<3 { episodes.append(episode(dayOffset * 10 + slot, on: day)) }
        }
        let result = plan(episodes)
        // 64 kept at three a day means everything up to and including day 21,
        // and one from day 22 — nothing later.
        XCTAssertEqual(result.last?.fireDate, localTime("2026-10-22 18:00"))
    }

    func testMostRecentlySavedWinsTheLastSlotOfADay() {
        let old = episode(1, title: "Saved Ages Ago", on: "2026-10-01",
                          savedAt: localTime("2026-01-01 10:00"))
        let newer = episode(2, title: "Saved Last Week", on: "2026-10-01",
                            savedAt: localTime("2026-09-25 10:00"))
        let newest = episode(3, title: "Saved Yesterday", on: "2026-10-01",
                             savedAt: localTime("2026-09-29 10:00"))
        let unknown = episode(4, title: "No Saved Date", on: "2026-10-01", savedAt: nil)

        let result = plan([old, newer, newest, unknown])
        XCTAssertEqual(result.count, 3)
        // A title with no recorded save date (anything from before v1.4)
        // sorts last rather than winning by accident.
        XCTAssertFalse(result.contains { $0.body.contains("No Saved Date") })
        XCTAssertTrue(result.contains { $0.body.contains("Saved Yesterday") })
    }
}

// MARK: - Manual-reminder precedence

final class AlertPlannerDedupeTests: XCTestCase {

    func testEpisodeReminderSetByHandSuppressesOurs() {
        let manual = [ManualReminder(identifier: "reminder.episode.555",
                                     fireDate: localTime("2026-10-01 09:00"),
                                     episodeID: 555)]
        XCTAssertTrue(plan([episode(1, on: "2026-10-01", episodeID: 555)], manual: manual).isEmpty)
    }

    func testTitleReminderOnTheSameDaySuppressesOurs() {
        let manual = [ManualReminder(identifier: "reminder.title.1",
                                     fireDate: localTime("2026-10-01 09:00"),
                                     mediaID: 1)]
        XCTAssertTrue(plan([episode(1, on: "2026-10-01")], manual: manual).isEmpty)
    }

    func testTitleReminderOnAnotherDayDoesNotSuppressOurs() {
        let manual = [ManualReminder(identifier: "reminder.title.1",
                                     fireDate: localTime("2026-11-20 09:00"),
                                     mediaID: 1)]
        XCTAssertEqual(plan([episode(1, on: "2026-10-01")], manual: manual).count, 1)
    }

    func testAReminderForAnotherTitleIsIrrelevant() {
        let manual = [ManualReminder(identifier: "reminder.title.999",
                                     fireDate: localTime("2026-10-01 09:00"),
                                     mediaID: 999)]
        XCTAssertEqual(plan([episode(1, on: "2026-10-01")], manual: manual).count, 1)
    }
}

// MARK: - Identity and copy

final class AlertPlannerContentTests: XCTestCase {

    func testIdentifierIsNamespacedAndCarriesTheFireDay() {
        let result = plan([episode(42, on: "2026-10-01")])
        XCTAssertEqual(result[0].identifier, "auto.episode.42.20261001")
        XCTAssertTrue(result[0].identifier.hasPrefix(AlertPlanner.autoPrefix))
    }

    func testBodyNamesTheSeasonAndEpisode() {
        let result = plan([episode(1, title: "Severance", on: "2026-10-01",
                                   season: 3, number: 7)])
        XCTAssertEqual(result[0].body, "Severance S3E7 airs today")
    }

    func testBodyStaysHonestWhenNumberingIsUnknown() {
        let result = plan([episode(1, title: "Severance", on: "2026-10-01",
                                   season: nil, number: nil)])
        XCTAssertEqual(result[0].body, "A new episode of Severance airs today")
    }

    func testAlertDeepLinksToTheSeries() {
        let result = plan([episode(42, on: "2026-10-01")])
        XCTAssertEqual(result[0].deepLink, DeepLink(id: 42, mediaType: .tv))
        XCTAssertEqual(result[0].kind, .episode)
    }
}

// MARK: - Reconciling

final class AlertSchedulerDiffTests: XCTestCase {

    private let alert = PlannedAlert(identifier: "auto.episode.1.20261001",
                                     title: "New episode",
                                     body: "Fixture S1E1 airs today",
                                     fireDate: localTime("2026-10-01 18:00"),
                                     deepLink: DeepLink(id: 1, mediaType: .tv),
                                     kind: .episode)

    func testMissingAlertsAreAdded() {
        let work = AlertScheduler.diff(plan: [alert], existing: [])
        XCTAssertEqual(work.add, [alert])
        XCTAssertTrue(work.remove.isEmpty)
    }

    func testAlreadyScheduledAlertsAreLeftAlone() {
        // Idempotence: the second reconcile of an unchanged plan is a no-op.
        let work = AlertScheduler.diff(plan: [alert], existing: [alert.identifier])
        XCTAssertTrue(work.add.isEmpty)
        XCTAssertTrue(work.remove.isEmpty)
    }

    func testNoLongerPlannedAlertsAreRemoved() {
        let work = AlertScheduler.diff(plan: [], existing: ["auto.episode.9.20260101"])
        XCTAssertEqual(work.remove, ["auto.episode.9.20260101"])
    }

    func testManualRemindersAreNeverRemoved() {
        // The single most important line in the file: a reconcile must never
        // cancel something the user set by hand.
        let work = AlertScheduler.diff(
            plan: [],
            existing: ["reminder.title.5", "reminder.season.5.2", "reminder.episode.77"])
        XCTAssertTrue(work.remove.isEmpty)
    }

    func testAMovedAirDateReplacesRatherThanDuplicates() {
        // The fire day is part of the identifier, so a rescheduled episode
        // arrives as one add and one remove.
        let work = AlertScheduler.diff(plan: [alert], existing: ["auto.episode.1.20260925"])
        XCTAssertEqual(work.add, [alert])
        XCTAssertEqual(work.remove, ["auto.episode.1.20260925"])
    }
}

// MARK: - Reading identifiers back

final class ReminderIdentifierTests: XCTestCase {

    func testMediaIDIsReadFromTitleAndSeasonReminders() {
        XCTAssertEqual(ReminderManager.mediaID(from: "reminder.title.550"), 550)
        XCTAssertEqual(ReminderManager.mediaID(from: "reminder.season.550.2"), 550)
    }

    func testEpisodeRemindersCarryAnEpisodeIDNotAMediaID() {
        XCTAssertNil(ReminderManager.mediaID(from: "reminder.episode.99"))
        XCTAssertEqual(ReminderManager.episodeID(from: "reminder.episode.99"), 99)
        XCTAssertNil(ReminderManager.episodeID(from: "reminder.title.550"))
    }

    func testOurOwnIdentifiersAreNotMistakenForReminders() {
        XCTAssertNil(ReminderManager.mediaID(from: "auto.episode.42.20261001"))
        XCTAssertNil(ReminderManager.episodeID(from: "auto.episode.42.20261001"))
    }

    func testGarbageIsRejected() {
        XCTAssertNil(ReminderManager.mediaID(from: "reminder.title.notanumber"))
        XCTAssertNil(ReminderManager.mediaID(from: "reminder"))
        XCTAssertNil(ReminderManager.mediaID(from: ""))
    }

    func testManualRemindersAreSiftedOutOfWhatIOSHolds() {
        let pending = [
            PendingRequest(identifier: "reminder.title.550", fireDate: now),
            PendingRequest(identifier: "reminder.episode.99", fireDate: now),
            PendingRequest(identifier: "auto.episode.42.20261001", fireDate: now),
            // A reminder with no readable fire date can't be reasoned about,
            // so it is left out rather than guessed at.
            PendingRequest(identifier: "reminder.title.551", fireDate: nil)
        ]
        let manual = AlertInputs.manualReminders(from: pending)
        XCTAssertEqual(manual.map(\.identifier), ["reminder.title.550", "reminder.episode.99"])
        XCTAssertEqual(manual[0].mediaID, 550)
        XCTAssertEqual(manual[1].episodeID, 99)
    }
}

// MARK: - Now streaming

final class AlertPlannerStreamingTests: XCTestCase {

    func testASingleChangeNamesTheTitleAndTheService() {
        let result = plan([], streamingChanges: [streaming(550, title: "Fight Club")])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].body, "Fight Club is now on Netflix")
        XCTAssertEqual(result[0].kind, .streaming)
        XCTAssertEqual(result[0].deepLink, DeepLink(id: 550, mediaType: .movie))
    }

    func testBodyStaysHonestWhenTheServiceIsUnknown() {
        let result = plan([], streamingChanges: [streaming(550, title: "Fight Club", service: nil)])
        XCTAssertEqual(result[0].body, "Fight Club is now streaming")
    }

    func testItFiresAlmostImmediately() {
        // "Now streaming" is news now, not at six o'clock.
        let result = plan([], streamingChanges: [streaming(550)])
        XCTAssertEqual(result[0].fireDate,
                       now.addingTimeInterval(AlertPlanner.streamingLead))
    }

    func testSeveralChangesCollapseIntoOneDigest() {
        // Three banners inside a minute is what teaches people to switch
        // notifications off.
        let result = plan([], streamingChanges: [streaming(1), streaming(2), streaming(3)])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].body, "3 titles from your watchlist are new on your services")
    }

    func testTheDigestCarriesEveryChangeItSpeaksFor() {
        // All three must be marked as told, or the two it didn't name would
        // be offered again on the next run.
        let changes = [streaming(1), streaming(2), streaming(3)]
        let result = plan([], streamingChanges: changes)
        XCTAssertEqual(Set(result[0].sourceChangeIDs), Set(changes.map(\.changeID)))
    }

    func testTheDigestHasNoDeepLink() {
        // Several titles, so there is no single right destination. Opening
        // the app is the answer — the briefing lists them.
        let result = plan([], streamingChanges: [streaming(1), streaming(2)])
        XCTAssertNil(result[0].deepLink)
        XCTAssertNil(result[0].subjectID)
    }

    func testASingleChangeCarriesItsOwnID() {
        let change = streaming(550)
        let result = plan([], streamingChanges: [change])
        XCTAssertEqual(result[0].sourceChangeIDs, [change.changeID])
    }

    func testEpisodeAlertsCarryNoChangeIDs() {
        // They are planned from a date, not from a detected change, so there
        // is nothing to mark as told.
        let result = plan([episode(1, on: "2026-10-01")])
        XCTAssertTrue(result[0].sourceChangeIDs.isEmpty)
    }

    func testAnOvernightDiscoveryWaitsForMorning() {
        let lateNight = localTime("2026-10-01 23:40")
        let result = plan([], streamingChanges: [streaming(550)], at: lateNight)
        XCTAssertEqual(result[0].fireDate, localTime("2026-10-02 09:00"))
    }

    func testASmallHoursDiscoveryWaitsForTheSameMorning() {
        let small = localTime("2026-10-01 04:10")
        let result = plan([], streamingChanges: [streaming(550)], at: small)
        XCTAssertEqual(result[0].fireDate, localTime("2026-10-01 09:00"))
    }

    func testStreamingComesBeforeTonightsEpisode() {
        let result = plan([episode(1, on: "2026-09-30")], streamingChanges: [streaming(550)])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].kind, .streaming)
        XCTAssertEqual(result[1].kind, .episode)
    }

    func testTheSameTitleGetsOneAlertADayAcrossBothKinds() {
        // A series whose episode airs tonight and which also just landed on
        // a service is still one interruption.
        let result = plan([episode(42, on: "2026-09-30")],
                          streamingChanges: [streaming(42, mediaType: "tv")])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].kind, .streaming, "the sooner one wins")
    }

    func testTheDigestIsExemptFromThePerTitleCap() {
        // It has no single subject, so it cannot collide with a title that
        // also has an episode tonight.
        let result = plan([episode(1, on: "2026-09-30")],
                          streamingChanges: [streaming(1, mediaType: "tv"), streaming(2)])
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.body.contains("2 titles") })
    }

    func testTheDailyCapStillApplies() {
        let manual = (900...902).map {
            ManualReminder(identifier: "reminder.title.\($0)",
                           fireDate: now.addingTimeInterval(3600), mediaID: $0)
        }
        XCTAssertTrue(plan([], streamingChanges: [streaming(1)], manual: manual).isEmpty)
    }

    func testNoChangesMeansNoDigest() {
        XCTAssertTrue(plan([], streamingChanges: []).isEmpty)
    }

    func testIdentifiersAreNamespacedAndStableWithinADay() {
        let single = plan([], streamingChanges: [streaming(550)])
        XCTAssertEqual(single[0].identifier, "auto.streaming.550.20260930")

        let digest = plan([], streamingChanges: [streaming(1), streaming(2)])
        XCTAssertEqual(digest[0].identifier, "auto.streaming.digest.20260930")

        // Planning twice inside the same day must not churn the schedule.
        XCTAssertEqual(plan([], streamingChanges: [streaming(550)])[0].identifier,
                       single[0].identifier)
    }
}
