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
