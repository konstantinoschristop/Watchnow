# Retention Release (v2.1) — Decision log

Every non-obvious decision, so a future session can pick this up cold.
Newest at the bottom. Format: **D-n · date · decision · why · status.**

Status legend: `proposed` (needs the dev's yes) · `accepted` · `superseded` · `rejected`.

---

## D-1 · 2026-09-13 · Docs live at `Watchnow/docs/retention-release/`, not the repo root
The git root is `Desktop/MyProjects`, shared by TapBasket, two screenshot sites and the marketing
pages. Putting a `docs/retention-release/` there would read as repo-wide. Keeping it under the app
folder keeps it attached to the thing it documents. The folder is not a member of any target, so it
never reaches the bundle and needs no `pbxproj` entry.
**Status: accepted** (reversible in one `git mv`).

## D-2 · 2026-09-13 · Prompt assumption 1 is false: persistence is UserDefaults + iCloud KVS
Not SwiftData, not Core Data, not CloudKit. `@UserDefault` JSON-encodes into `UserDefaults.standard`
and `CloudSync` mirrors a fixed key set into `NSUbiquitousKeyValueStore`.
Consequences carried into the plan: (a) the widget-snapshot-in-an-App-Group design is unchanged and
still correct — arguably more so, since a widget *could* read a shared `UserDefaults` suite but only
after migrating the whole store, which is forbidden; (b) the onboarding gate has no CloudKit import
notification to wait on and must key off `CloudSync.didMergeRemoteChanges` instead (see D-8);
(c) adding a synced flag is one line in `CloudSync.syncedKeys`.
**Status: accepted** (fact, not a choice).

## D-3 · 2026-09-13 · Phase 3's availability modules are cut; the existing pipeline is extended
`WatchlistChangeMonitor` + `ChangeClassifier` + `WatchlistChangeStore` + `WatchlistSnapshot` already
constitute an availability snapshot store, a batched refresher and a diff engine: every saved title
is fetched from `/watch/providers` every 12 hours and its flatrate provider ids are diffed against a
persisted snapshot to emit `.streamingAvailability`. The same snapshot already persists
`nextEpisodeID` / `nextEpisodeAirDate` — the episode planner's entire input. There is even an unused
`shouldNotify` policy stub in the monitor, commented *"this exists so a future release can notify
without redesigning anything"*.
Building `AvailabilitySnapshot(Store)` / `AvailabilityRefresher` / `AvailabilityDiffEngine` beside
that would be the second pipeline the prompt itself forbids two sections later. Phase 3 instead
adds: a batch cap with oldest-`lastCheckedAt`-first ordering, a background entry point, and a
hand-off from the monitor's output into `AlertPlanner`. `shouldNotify` moves into the planner,
because policy now lives there.
**Status: accepted 2026-09-13 by the dev.** Phase 3 is rescoped accordingly.

## D-4 · 2026-09-13 · No `FollowService`, no follow flags — an opt-out set instead
Auto-follow is on by default for every save, so a per-title follow flag is a duplicate of the
watchlist plus a sync-merge hazard (device A saves and writes a flag; device B holds the title from
an older sync with no flag — last-writer-wins over KVS then decides whether the user is subscribed
to alerts, which is not a coin worth flipping). Model it as:
`followed ≡ in the watchlist ∧ not in AlertPreferences.optedOut`. Only the opt-outs and the two
global bools are stored and synced. `WatchlistManager.removeFromWatchList` already forgets
`addedDates` and `providers` for a removed title; the opt-out joins them there.
**Status: accepted — implemented in Phase 1** as `AlertPreferences.optedOutIDs`.

## D-5 · 2026-09-13 · No `Clock`/`DateProvider` protocol; `now: Date = Date()` stays the idiom
`ChangeClassifier`, `WatchlistChangeStore` and `WhatsNewViewModel` are all pure-with-injected-`now`
already and are tested that way against a frozen `fixedNow`. A clock protocol would be exactly the
"second pattern" the prompt's coding standards forbid, for no extra testability. A protocol *is*
warranted for `AlertScheduler`'s three `UNUserNotificationCenter` calls, because those cannot be
made pure — but the planner above it takes value types and needs no fake.
**Status: proposed.**

## D-6 · 2026-09-13 · No mark-as-watched exists; three requirements depend on it
`PrimaryActionRow` offers Watch Later / Trailer / I-like-this. The "Watched" in its header comment
is aspirational; there is no store, key or UI anywhere. Blocked by this: the "third mark-as-watched"
review trigger, the widget's "never show a watched title" invariant, and "a tracked, **unwatched**
title becomes streamable".
Recommendation: a minimal Watched toggle as a new **Phase 1.5** — one synced `Set<Int>`, a control
on the details screen and the watchlist grid, exclusion from Movie Night decks. It is small, it
makes three requirements honest instead of fudged, and closing the loop on a tracker is itself a
return trigger.
**Status: accepted 2026-09-13 by the dev — build it, as Phase 1.5.**

## D-7 · 2026-09-13 · New alert identifiers are namespaced `auto.*`; manual `reminder.*` is untouchable
The existing bell writes `reminder.title.<id>`, `reminder.season.<id>.<n>`, `reminder.episode.<id>`
and mirrors them in the `scheduledReminderIDs` default. `AlertScheduler.reconcile` must only ever
add or remove `auto.episode.*` / `auto.streaming.*`, so a reconcile can never cancel something the
user set by hand. When trimming to 64, manual reminders are counted but never evicted.
**Status: proposed.**

## D-8 · 2026-09-13 · The onboarding "restore wait" is KVS-shaped, not CloudKit-shaped
There is no import-progress signal. `CloudSync.reconcileAtLaunch()` reads whatever the local KVS
cache already holds, which on a fresh install may be nothing until the daemon syncs. The only
available event is `CloudSync.didMergeRemoteChanges`. So: when `CloudSync.isAvailable`, wait up to
3s for that notification carrying the `watchlist` key or for a non-empty watchlist, behind a light
"Restoring your watchlist…" indicator; when the user is not signed into iCloud, skip the wait
entirely rather than burning 3 seconds on a fresh install that can never restore.
**Status: proposed.**

## D-9 · 2026-09-13 · Coach's 5-title minimum makes the specified onboarding finish impossible
`MovieCoachService.minimumWatchlistSize = 5`, by design — below that Coach "would be guessing
dressed up as advice". Onboarding step 3 asks for three saves, so a Coach verdict at finish can
never fire on a fresh install as specified.
Recommendation: count step 2's five **loved** picks toward Coach's history. They are a stronger
taste signal than a save, it needs no UX change, and it leaves the 5-title bar intact for everyone
else. Alternatives considered: raise step 3 to 5 saves (more friction at the worst moment);
lower `minimumWatchlistSize` (degrades Coach for every user to serve one screen).
**Status: accepted 2026-09-13 by the dev** — the five loved picks count toward Coach's history.

## D-10 · 2026-09-13 · The bell must appear for airing series, not just unreleased titles
`ContentDetailsView.navBarTrailingView` renders the bell only when `futureReleaseDate != nil`. A
currently-airing series — the exact target of "new episode" alerts — has no bell. Reusing the bell
as the per-title alert control therefore requires showing it whenever the title has a
`next_episode_to_air`. This is a visible change to an existing screen, so it is called out rather
than slipped in.
**Status: accepted — implemented in Phase 1**, as `ContentDetailsViewModel.BellMode` (see D-21).

## D-11 · 2026-09-13 · `ReviewRequestManager` is modified, not replaced; recommend keeping the save trigger
It already exists (3 saves + 2 days + once per version). The prompt's triggers — Movie Night match
or third mark-as-watched, once per 120 days — are strictly *narrower*, and the store currently shows
zero ratings. Narrowing the funnel to fix "no ratings" is the wrong direction. Recommend the union:
the two new high-intent triggers **plus** the existing save-based one, under a single 120-day
throttle. Also: the Movie Night results screen already fires an AdMob interstitial
(`InterstitialAdManager.presentIfAllowed()`), so the review prompt must yield to it rather than
stack on top.
**Status: accepted 2026-09-13 by the dev** — union of all three triggers, one 120-day throttle.

## D-12 · 2026-09-13 · "Data Not Collected" is inconsistent with the shipping AdMob integration
The app links GoogleMobileAds + GoogleUserMessagingPlatform, starts the SDK unconditionally at
launch, presents a UMP consent form and renders banner, native and interstitial ads. The app's own
`PrivacyInfo.xcprivacy` declaring no collected types is correct (SDKs ship their own manifests), but
the App Store **privacy label** must cover SDK collection. Nothing in this release changes that
either way, and ASC metadata is out of scope per the brief — recorded because the prompt leans on
the label in its Context, its Constraints and its Featuring Nomination pitch. The constraint this
release will actually hold to: **no new data collection, no new SDK, no new network destination.**
**Status: accepted as a flag; no action in this release.**

## D-13 · 2026-09-13 · Localization: one String Catalog + `SWIFT_EMIT_LOC_STRINGS`, no per-screen catalog
There is no `.xcstrings` today and every user-facing string in the app is a hard-coded Swift
literal. Writing only the new screens against a catalog would create two conventions in one app.
Proposal: add a single `Localizable.xcstrings` and set `SWIFT_EMIT_LOC_STRINGS = YES`, so Xcode
auto-extracts every existing `Text("…")` app-wide. The whole app becomes localization-ready with
zero code churn and new screens keep writing plain literals exactly like the old ones.
**Status: accepted 2026-09-13 — default taken, not explicitly asked. Say so before Phase 1 to change it.**

## D-14 · 2026-09-13 · The widget extension target is created by hand, in Xcode, by the developer
`project.pbxproj` is `objectVersion 54` with explicit file references and no file-system-synchronized
groups. Adding an app-extension target means fabricating a native target, a product reference, a
copy-files phase, an embed phase, two build configurations and an entitlements file by hand — a
reliable way to produce a project that opens and then fails to build or to sign. The dev adds the
target and the App Group capability in Xcode; every line of Swift inside it is written here. Same
division of labour as the iCloud KVS capability in v1.x.
Corollary that applies to *every* phase: each new `.swift` file needs four `pbxproj` entries
(`PBXBuildFile`, `PBXFileReference`, the group's `children`, the target's `Sources` phase) or it
compiles to nothing and fails silently at runtime.
**Status: accepted** (a property of the project, not a preference).

## D-15 · 2026-09-13 · Settings gets a home: a sheet from the Watchlist toolbar
There is no settings surface anywhere in the app — four tabs, no gear, no preferences row. The
release needs one for the two global alert toggles and the "notifications are off, here's how to
turn them on" row, and there are three existing things with nowhere to live that belong in it:
streaming-service selection (today only reachable through Movie Night setup), the `SyncStatus`
"Synced via iCloud" caption (built, unused outside Movie Night), and the TMDB / JustWatch
attributions. In DEBUG it also hosts the Phase 2 developer menu, next to the existing What's New
hammer in the same toolbar.
**Status: accepted — implemented in Phase 1** as `Screens/Settings/SettingsView.swift` (see D-19, D-20).

## D-16 · 2026-09-13 · Onboarding must run *after* the UMP consent form, never beside it
`WatchnowApp` presents the GDPR consent form from a `.task` on `ContentView`, on the same launch a
fresh install would show onboarding. Two modals racing for the same first second. Consent goes
first (it is a legal precondition for personalised ads and it is already shipping); onboarding
waits for it to finish. The notification-permission explainer is third, at the end of onboarding —
never at launch, per the brief.
**Status: proposed.**

## D-17 · 2026-09-13 · Baseline build is green with three pre-existing warnings
`xcodebuild -scheme Watchnow -destination 'generic/platform=iOS Simulator' build` → exit 0.
Pre-existing first-party warnings: `WatchnowApp.swift:79` (async alternative available),
`ReviewRequestManager.swift:50` (no async operation in `await`), `BannerAdView.swift:69`
(deprecated adaptive banner size). "Zero new warnings" is measured against exactly this list.
The `ReviewRequestManager` one gets fixed for free in Phase 6.
**Status: accepted.**

## D-18 · 2026-09-13 · Unused entitlements flagged, not removed
`Watchnow.entitlements` declares `aps-environment` (remote push — nothing registers for it) and a
CloudKit container + `icloud-services: [CloudKit]` (nothing uses CloudKit; KVS is the only sync).
They are harmless but they actively mislead anyone reading the architecture from the entitlements
file — which is how this session's first wrong assumption would have been formed. Proposed for
removal as Phase 6 tidy-up, *after* the App Group is added and verified, so entitlement churn is not
mixed into the phase where signing matters most.
**Status: proposed.**

---

# Phase 1 — Alert preferences, permission, Settings

## D-19 · 2026-09-13 · Settings is a plain `Form`, not the app's card vocabulary
The app draws content surfaces by hand out of `AppRadius` / `.appFont` / material fills, and that is
right for posters, briefings and swipe decks. A settings list is not a content surface — it is a
system shape, and the system shape is already pixel-correct at every Dynamic Type size, correct
under VoiceOver, and correct in both colour schemes without a line of layout code. Reaching for the
card vocabulary here would have meant re-earning all of that by hand. The design tokens are not
abandoned; they simply do not apply to this screen.
**Status: accepted.**

## D-20 · 2026-09-13 · The streaming-services picker is deferred from Settings to Phase 4
`StreamingPreferences` is today only editable inside Movie Night's setup screen, and Settings is the
obvious home for it. But Phase 4's onboarding step 1 needs the same provider grid, and building one
picker in Phase 1 and a second in Phase 4 is how an app ends up with two. Phase 4 builds the
reusable grid for onboarding; Settings picks it up in the same phase for free.
**Status: accepted.**

## D-21 · 2026-09-13 · The bell has two modes and never both at once
`ContentDetailsViewModel.BellMode`: an unreleased title keeps the manual release reminder the bell
has meant since v1.3, byte for byte; anything already out and saved gets the per-title mute for the
automatic alerts. They are mutually exclusive in practice — a title with a future release date is by
definition not yet airing — so one glyph carries both without ambiguity. A saved-and-unreleased
title shows the reminder, and flips to the mute control once it is out, which is the moment the
automatic alerts can first do anything anyway.
Two consequences worth stating: the bell now appears on *every* saved title, not just unreleased
ones, which is the release's promise made visible; and it renders `!isOptedOut` — the per-title
decision — rather than "will an alert actually fire", because gating it on the global switches would
make a tap do nothing. The truthful version of that lives in the bell's accessibility hint, which
reads the global state through `AutoAlertPolicy` and says "Alerts are switched off for every title
in Settings" when that is the case.
**Status: accepted.**

## D-22 · 2026-09-13 · The permission explainer is hosted by `ContentView`, not by the saving screen
The save that triggers it happens on a details screen or in a list row; the sheet is presented from
the app root. That way it survives the user navigating away in the second between saving and
deciding, and one implementation serves both save call sites. Same reasoning that makes
`DeepLinkRouter` and `WhatsNewViewModel` shared singletons.
It is offered 800ms after the save so the "Added to Watchlist" toast reads first — the same
courtesy `ReviewRequestManager` already pays, shorter because this is part of the same gesture
rather than an interruption.
**Status: accepted.**

## D-23 · 2026-09-13 · `AlertPreferences.didShowPermissionExplainer` is set on *both* outcomes
Accept and decline both mark the explainer as spent, and it is written *before* the system prompt is
raised rather than after. That is what makes "never re-prompt after denial" true even if the app is
killed while iOS's alert is on screen. The only route back is the Settings screen, which is exactly
what the brief asks for.
**Status: accepted.**

## D-24 · 2026-09-13 · `pbxadd.py` — a scripted way to register new files
This project has no file-system-synchronized groups, so every new `.swift` needs four `pbxproj`
entries or it silently never compiles. Phase 1 wrote a small helper that does all four (plus group
creation) rather than hand-editing five times. It lives in the session scratchpad, not the repo —
it is scaffolding for this release, and a script that mutates `project.pbxproj` is not something
that should outlive the work and get run by accident.
One trap it now guards against, found the hard way: a bare `\t\t<id> /* ` anchor also matches the
id where it is *listed* inside a parent group's `children` (four tabs of indent), so the first
attempt filed three files under `Preview Content` and two under `Responses`. Anchor on
`\n\t\t<id> /* ` — the definition, not the reference.
**Status: accepted.**

---

# Phase 2 — Alert planning and background refresh

## D-25 · 2026-09-13 · Episode data comes from `WatchlistSnapshot`, not a fresh TMDB call
`WatchlistChangeMonitor` already refreshes every saved title twice a day and persists
`nextEpisodeID` / `nextEpisodeAirDate` in the What's New snapshot. The planner reads that rather
than fetching, which means a plan costs zero requests and works offline. Two optional fields were
added to the snapshot — `nextEpisodeSeason` / `nextEpisodeNumber` — so an alert can say "S3E7"
instead of "a new episode".
They are `Int?` with a `nil` default for the reason `SavedProvider.kind` documents: `@UserDefault`
decodes the whole snapshot table in one pass, so a non-optional addition would throw `keyNotFound`
on the first pre-existing record and silently discard every other snapshot with it.
**Status: accepted.**

## D-26 · 2026-09-13 · The fire *day* is part of the alert identifier
`auto.episode.<mediaID>.<yyyyMMdd>`. When TMDB moves an air date, the old identifier simply stops
being planned and a new one appears, so `AlertScheduler` heals the schedule with a plain
add/remove diff and no special case for rescheduling. It also makes the one-alert-per-title-per-day
cap true by construction rather than by enforcement.
**Status: accepted.**

## D-27 · 2026-09-13 · The scheduler does not inherit `ReminderManager`'s 3-second DEBUG trigger
`ReminderManager.schedule` fires every manual reminder ~3s after it is set in Debug builds, which is
right for testing a deep link and wrong for anything that reconciles against pending fire dates.
`LiveNotificationCenterClient.add` always builds a real calendar trigger. The debug menu's "Fire
sample alert" covers the "does a delivery actually work" question instead, and the menu's footer
says plainly that manual reminder dates shown there are not the real ones.
**Status: accepted.**

## D-28 · 2026-09-13 · An unauthorized reconcile leaves the schedule alone rather than tearing it down
If notifications are off, nothing would be delivered, so nothing is worth scheduling — but the
existing requests are not removed either. If the user turns notifications back on, the next
reconcile finds the schedule already correct instead of rebuilding it from nothing. The outcome
reports `skippedUnauthorized` so the debug menu can tell that apart from "nothing needed doing".
**Status: accepted.**

## D-29 · 2026-09-13 · The foreground pass plans but does not sync
`WhatsNewViewModel.checkOnLaunch` already drives `WatchlistChangeMonitor` on launch and on every
return to the foreground. A second sync beside it would double every saved title's request count
for no new information. `runForegroundPass` takes whatever the monitor last learned and makes the
schedule agree with it; only the background task and the debug button sync.
**Status: accepted.**

## D-30 · 2026-09-13 · `BGAppRefreshTask` crosses to the main actor in a box
The task isn't `Sendable` and the pipeline it drives is `@MainActor`, which Swift 6 rejects outright.
iOS hands the task over on one queue and only ever expects `expirationHandler` and
`setTaskCompleted` on it, so a small `@unchecked Sendable` box is honest about how narrow that
contract is — the same bargain `ServiceInvocation` and `NotificationCenterDelegate` already make in
this codebase. `taskIdentifier` is `nonisolated` so `register()` can run from `WatchnowApp.init`,
which is where it has to run: iOS traps on an identifier not declared in
`BGTaskSchedulerPermittedIdentifiers`, and registration must happen before launch completes.
**Status: accepted.**

## D-31 · 2026-09-13 · An episode airing today after 18:00 gets no alert
The planner drops any fire date already in the past, so saving a series at 20:00 on the day its
episode airs produces nothing. Considered firing "soon" instead and rejected: it adds a branch for
a narrow case, and in normal use the plan for today's episode was made yesterday or earlier, when
18:00 today was still ahead. Worth revisiting only if it shows up in real use.
**Status: accepted, with the trade-off named.**

## D-32 · 2026-09-13 · Verified on device, including the removal path
Saved series → snapshot → policy → plan → iOS. Proven on an iPhone 17 Pro simulator: the debug menu
reported `1 dated → 1 planned`, iOS held `auto.episode.314939.20260920` at 20 Sep 18:00, a second
foreground pass left it at exactly one pending (idempotent), and switching "Episode alerts" off
reconciled to `+0 / −1`.
One trap for anyone repeating this with a hand-edited fixture: `@UserDefault` stores `Data`, so a
plist edit that writes the JSON back as a *string* makes the app decode nothing at all and report an
empty store — which looks exactly like a broken pipeline.
**Status: accepted.**

---

# Phase 1.5 — Mark as watched

## D-33 · 2026-09-13 · Marking watched does not unsave
The watchlist becomes a record of what you meant to watch and what you did. Throwing the entry away
at the exact moment it finally means something would be backwards, and it would destroy the only
signal the widget, the alerts and the review prompt need. Stored as id → date rather than a set, the
same shape as `WatchlistManager.addedDates`, because the date is what lets anything later say "you
watched this in March" or count the last three. Synced: having seen something is a fact about the
person, not the phone.
**Status: accepted.**

## D-34 · 2026-09-13 · Watched surfaces: a third pill on details, a context action and a dim in the grid
The pill is its own full-width row for the same reason the taste button is — "Mark as watched" does
not survive a third of the width, and squeezing it would take "Watch Later" down with it. In the
grid the cover is dimmed to 0.6 and gains a checkmark badge; desaturating instead was tried in
thought and rejected, because a wall of grey covers is hard to read past and "done" should not make
the artwork look broken. Both the dim and the badge are purely visual, so `accessibilityDescription`
appends "watched" for VoiceOver.
`watchedIDs` is passed into the grid as a `Set<Int>` rather than asked per cell, for the reason the
existing `streamingProvider` comment already documents: `@UserDefault` decodes the whole table on
every access, so a per-cell read would be one full `JSONDecoder` pass per cover per render.
**Status: accepted.**

## D-35 · 2026-09-13 · Not built: a watched filter in the watchlist
Watched titles stay in place, dimmed. A "Hide watched" filter would sit next to the folder chips,
which is a busier surface than it looks, and the dim already answers "have I seen this" at a glance.
Worth adding if the list gets long enough that it stops being enough — noted rather than done.
**Status: accepted, scope deliberately left out.**

---

# Phase 3 — Now streaming alerts

## D-36 · 2026-09-13 · No new availability modules; the existing monitor got a cap
As agreed in D-3. `WatchlistChangeMonitor` gained `maxTitlesPerRun = 40` and oldest-`lastCheckedAt`-
first ordering, so a long watchlist is walked across several runs instead of in one burst. Titles
with no snapshot sort first — they have never been checked, and until they have a baseline they can
produce nothing. Ties break on id so the order is deterministic.
Nothing else was built: the snapshot store, the batched refresher and the diff engine the brief
asked for all already existed and are now feeding two consumers instead of one.
**Status: accepted.**

## D-37 · 2026-09-13 · `shouldNotify` moved from the monitor into the planner
The monitor's unused `shouldNotify` / `notificationCooldown` stub is gone. Its job is now split
where each half belongs: `AlertInputs.streamingChanges` answers the store-shaped questions (do they
have this service, have they watched it, have they muted it, were they told already) and
`AlertPlanner` answers the scheduling-shaped ones (caps, quiet hours, digest). A cooldown constant
floating beside a detector could never have cooperated with the daily caps; now there is one place
that decides how much noise a day may contain. Its test moved to `AlertPlannerTests` with it.
**Status: accepted.**

## D-38 · 2026-09-13 · `ChangeMetadata` carries the provider id
Answering "is this one of *their* services?" by parsing the provider id back out of the change's
composite id would have made the id format load-bearing for a second reason. An optional
`providerID` on the metadata is additive, decodes as nil for anything written before v2.1, and a nil
is read as "unknown service", which never notifies. Conservative in exactly the direction this
feature should be.
**Status: accepted.**

## D-39 · 2026-09-13 · The digest has no deep link
"3 titles from your watchlist are new on your services" has no single right destination, and opening
one of the three would be a small lie. Tapping it opens the app, where "While You Were Away"
presents itself on launch and lists exactly those changes. That also makes the digest exempt from
the per-title-per-day cap by construction — it has no subject to collide with.
**Status: accepted.**

## D-40 · 2026-09-13 · An alerted-change ledger, device-local
`AlertScheduler`'s reconcile is idempotent only while a notification is still *pending*. Once it has
fired it leaves the pending list, so the next plan would cheerfully schedule it again — every run,
until the user happened to open the app and spend the change. `AlertPreferences` now keeps the last
300 `WatchlistChange` ids it has alerted on, and only ids that iOS actually accepted are recorded:
an alert that was capped or rejected is still owed.
Device-local rather than synced. Notifications are delivered per device, so being told once on the
phone should not silence the iPad the user actually picks up — the same reasoning that keeps What's
New's seen-state off iCloud.
**Status: accepted.**

## D-41 · 2026-09-13 · A notification does not suppress the briefing card
A change that produced an alert still appears in the next "While You Were Away" briefing. They are
different surfaces with different lifetimes: a banner is missed, swiped away, or read on a locked
screen, and the briefing is the place you go to catch up deliberately. Suppressing the card would
punish the user for having notifications on. The store stays the single source of truth for both;
only the ledger differs, and it governs notifications alone.
**Status: accepted.**

## D-42 · 2026-09-13 · Verified end to end on device, with real TMDB data
The fixture was honest: Mayday's snapshot had its `providerIDs` emptied and the user's services set
to Apple TV+ (350), so the *real* classifier diffed real availability and produced a genuine
`streamingAvailability` change. It flowed through every filter and arrived as a delivered banner
reading "Now streaming — Mayday is now on Apple TV". Afterwards the plan correctly reported
`0 streaming`, because the ledger had recorded it: the alert had been sent, and the whole point is
that it is not sent twice.
**Status: accepted.**

---

# Phase 4 — Onboarding and Coach gating

## D-43 · 2026-09-13 · Coach gating needed no migration; only its arithmetic changed
As predicted in Phase 0: there is exactly one Coach entry point, `MovieCoachView`, and it already
renders nothing at all unless `MovieCoachService.isReady`. No `CoachAvailability` wrapper was added
— a new type whose whole body forwards to an existing one earns nothing.
What did change is D-9: `hasEnoughHistory` now counts `knownTitleCount` — saved ids unioned with
`TasteProfile.likedIDs` — rather than saves alone. Onboarding asks for five loves and three saves,
and a love is the stronger signal of the two; keeping the bar at "saves only" would have kept Coach
silent for precisely the user who had just told it the most. Verified on device: the finish screen
showed the Coach card rather than the warm-up hint.
**Status: accepted.**

## D-44 · 2026-09-13 · The finish screen is part of onboarding, not three modals over the watchlist
The brief asks for: land on the Watchlist, then a Coach verdict, then the permission explainer.
Chaining two sheets on top of a freshly-revealed watchlist is fiddly to sequence and reads as being
handed three things at once. Instead onboarding has a fourth internal step — "You're all set" —
carrying the three saved covers and the Coach verdict, and the permission explainer is presented
*after* dismissal, over the watchlist. The user still meets both, in the stated order, in one
continuous flow.
Completion is marked on *arrival* at that screen, not on leaving it, so neither Coach nor the
notification prompt is ever a condition of having been onboarded.
**Status: accepted, with the deviation named.**

## D-45 · 2026-09-13 · Onboarding runs after the consent form, and this is a real dependency
`WatchnowApp` presents the UMP consent form and now awaits it before `OnboardingCoordinator
.evaluate()`. Consent has the legal claim on going first — it governs whether the ads already
shipping may be personalised — and two modals racing for the first second of a fresh install is a
bad first impression.
Worth flagging: the file's own header notes that a stalled consent flow used to block ads forever,
which is why `MobileAds.start()` was uncoupled from it. Onboarding is now coupled to it instead. On
the simulator the callback returns promptly, but if it ever hangs, the first run hangs with it. A
timeout around the consent wait is the obvious hardening and is **not** done — noted rather than
guessed at, because the right ceiling depends on real UMP behaviour in the field.
**Status: accepted, with a known risk recorded.**

## D-46 · 2026-09-13 · Step 2 uses trending, not a hand-curated list of classics
"~30 well-known titles across genres and both media types" could be a static list, which would be
more controllable and would start ageing the day it shipped. Trending is what people are actually
watching, comes region-flavoured for free, and is never empty. Films and shows are interleaved so
the grid reads as "both" rather than as a block of one followed by a block of the other.
Step 3 is personalised from step 2 through TMDB's own recommendations for the loved picks — three
requests — and falls back to trending when the user skipped step 2 or TMDB had little to say.
Verified on device: loving Moana produced a step-3 grid of family adventure titles, not generic
trending.
**Status: accepted.**

## D-47 · 2026-09-13 · One provider picker, two screens, and Movie Night keeps its own chips
`StreamingProviderCatalog` now owns the curated subscription list and its ordering, which used to
live inside `MovieNightViewModel`. `ProviderPickerGrid` is the shared chip layout, used by
onboarding step 1 and the new Settings "Your services" section — closing D-20.
Movie Night's own chips were left alone. They carry that screen's motion and layout, and migrating a
shipped screen for visual uniformity is risk without benefit; it reads the same catalogue, so the
list and its order can no longer drift. Two chip *views*, one source of truth.
**Status: accepted.**

## D-48 · 2026-09-13 · The gate's hardest case was verified by accident, and it passed
The first attempt at a clean-install walkthrough showed no onboarding at all. The cause was the
right one: `simctl uninstall` leaves the KVS store behind, `CloudSync.reconcileAtLaunch` pulled a
three-title watchlist back, and the gate correctly answered `.skip` — which is precisely the
second-device scenario it exists for. Seeing the real flow required clearing
`data/Containers/Data/InternalDaemon/*/com.apple.kvs` as well.
Worth writing down for whoever tests this next: on a simulator the KVS daemon logs
`Error synchronizing with cloud … "No account"`, so `CloudSync.isAvailable` is false and the gate
takes the no-iCloud path immediately. The three-second restore wait cannot be exercised there at all
— it needs a signed-in device.
**Status: accepted.**

## D-49 · 2026-09-13 · The finish screen fetches a full Coach context, not a thin one
Four parallel requests (details, providers, credits, keywords) rather than the two it started with.
`MovieCoachContext` reasons from cast and themes, so handing it empties would have made the first
Coach verdict the user ever sees the most generic one the app can produce. On the simulator the
generation itself fails — the on-device model is not really available there — and the card falls
back to its existing "Couldn't get a read on this one · Retry" state rather than breaking the
screen.
**Status: accepted.**

## D-50 · 2026-09-13 · Not built: a watchlist filter, and localization is still outstanding
The empty state was rewritten with a "Browse Trending" action that switches tabs, closing the brief's
empty-state item. Two things from earlier phases remain open and are called out so Phase 6 does not
discover them: the `Localizable.xcstrings` catalog agreed in D-13 has not been added, and the watched
filter deferred in D-35 is still deferred.
**Status: accepted, tracked for Phase 6.**

---

# Phase 5 — cut

## D-51 · 2026-09-13 · The "Tonight's Pick" widget is cut from this release
Dropped by the dev after weighing it against the four mechanisms already built.
Three reasons, in order of weight. There is no API to add a widget for someone: it takes a
long-press, a +, a search, a size choice and a placement — five deliberate steps most people never
perform, so its reach is a self-selected minority. It was the only phase requiring a new target and
new entitlements, i.e. the only signing risk in the release. And its effect could never be isolated
in App Store Connect, which is the only measurement this release has.
If it returns in v2.2 it returns with an in-app nudge — a widget nobody adds is worse than no
widget, because it cost a phase. Everything it would have needed already exists:
`WatchlistManager.providers` is refreshed twice daily, `WatchedStore` says what is finished, and
`StreamingPreferences` says which services count.
**Status: accepted 2026-09-13 by the dev.**

---

# Phase 6 — Review prompt, polish, release

## D-52 · 2026-09-13 · The Movie Night review prompt fires on acting, not on arriving
The results phase already fires the app's one interstitial. A review sheet raised behind a
fullscreen ad is simply discarded by StoreKit — which would spend the four-month throttle on a
prompt nobody saw. Asking when the user taps "View details" on the match puts it after the ad has
been dismissed, and at a better moment anyway: they have a decision and they are taking it.
Deliberately done without touching `InterstitialAdManager` to add a "did it present" accessor —
that file has uncommitted work in the tree from a parallel screenshot-mode change, and committing
someone else's half-finished work to read one boolean is a bad trade.
**Status: accepted.**

## D-53 · 2026-09-13 · Upgrading users carry their old prompt marker forward
v2.0 recorded only *which version* last prompted, so an upgrading user has no date to throttle
against. On first launch of 2.1, a marker matching the running version is converted to
"prompted just now", starting the 120-day clock from the upgrade. Asking someone twice in a week is
the one outcome worth ruling out; being four months late costs nothing. A marker from an older
version is discarded without throttling.
**Status: accepted.**

## D-54 · 2026-09-13 · The String Catalog is wired, but it needs opening in Xcode once
`Localizable.xcstrings` is in the project as a resource and `SWIFT_EMIT_LOC_STRINGS = YES` is set on
both app configurations. A build now emits 302 `.stringsdata` tables — every user-facing literal in
the app, including every screen from this release, without a line of Swift changing.
The catalog file itself stays empty until someone opens it in Xcode, which is what syncs the
extracted strings into it; `xcodebuild` alone will not populate it. So the app is *localisation-
ready* but not yet *localised*, and that last step is a manual one. Recorded in the release notes'
pre-submission list rather than left as a surprise.
**Status: accepted, with the manual step named.**

## D-55 · 2026-09-13 · Two real accessibility bugs found at AX3, both fixed
Neither was visible at default text size.
A provider chip sizes to its own text, so "Amazon Prime Video" at an accessibility size was wider
than the phone and ran off the right edge. `ProviderPickerGrid` now switches from a wrapping chip
flow to full-width rows once `dynamicTypeSize.isAccessibilitySize`, with the label wrapping to two
lines and a selection circle on the trailing edge. Chips are a compact-size affordance; past that
point they have nowhere to grow.
Onboarding's header was pinned above the scroll view, and a five-line title left barely one row of
choices visible between it and the footer. The header now scrolls with the content; only the footer
stays pinned. Verified at AX3: all eight services reachable, poster grid holds three across with
clean truncation.
**Status: accepted.**

## D-56 · 2026-09-13 · The unused push and CloudKit entitlements stay, for now
D-18 proposed removing `aps-environment` and the CloudKit container as a Phase 6 tidy-up, on the
reasoning that the App Group work would already have touched signing. With Phase 5 cut there is no
signing work in this release at all — so entitlement churn would be the *only* provisioning change,
introduced immediately before submission. That is exactly the kind of thing you do not want to
discover at upload. They are misleading but harmless; remove them in a quiet moment on a non-release
branch.
**Status: superseded by D-51; deferred deliberately.**

## D-57 · 2026-09-13 · Release audit
- Network destinations: four, all pre-existing — `api.themoviedb.org`, `image.tmdb.org`,
  `themoviedb.org`, `youtube.com`. This release adds none.
- `PrivacyInfo.xcprivacy`: unchanged and still correct. No new data types;
  `NSPrivacyAccessedAPICategoryUserDefaults` was already declared.
- No new third-party dependencies.
- `Info.plist` gained `BGTaskSchedulerPermittedIdentifiers` and `UIBackgroundModes: fetch`.
- Warnings: the Phase 0 baseline had three first-party warnings. Phase 6 fixed one
  (`ReviewRequestManager`'s no-op `await`, in a file it rewrote), leaving two — both in files this
  release never touched.
**Status: accepted.**
