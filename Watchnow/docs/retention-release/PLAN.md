# Retention Release (v2.1) — Phase 0: Discovery & Plan

Status: **Phase 0 complete, awaiting review. No code changed.**
Written: 2026-09-13 · Branch `v2.1` · App at MARKETING_VERSION 2.0

---

## 1. What the codebase actually is

| Question | Answer |
|---|---|
| Repo root | `/Users/k.christopoulos/Desktop/MyProjects` (shared with TapBasket + screenshot sites) |
| Xcode project | `Watchnow.xcodeproj`, `objectVersion = 54` — **no** file-system-synchronized groups |
| Targets | `Watchnow` (app), `WatchnowTests` (XCTest, in the `Watchnow` scheme) |
| Swift / min iOS | `SWIFT_VERSION = 6.0` (Swift 6 language mode), `IPHONEOS_DEPLOYMENT_TARGET = 18` |
| Bundle id / team | `k.christopoulos.Watchnow` / `YC87BA998K`, automatic signing |
| Device family | iPhone only (`TARGETED_DEVICE_FAMILY = 1`), portrait only |
| SPM deps | Kingfisher, GoogleMobileAds, GoogleUserMessagingPlatform, AlertToast |
| Info.plist | Real file at `Watchnow/Info.plist` (`INFOPLIST_FILE`, not generated) |
| Schemes | `Watchnow`, `Watchnow release` (both shared) |

### Persistence and iCloud sync — **not** SwiftData, **not** Core Data, **not** CloudKit

- Everything is `UserDefaults.standard`, written through one property wrapper:
  `@UserDefault` in [WatchlistManager.swift:11](../../Helpers/WatchlistManager.swift#L11). It JSON-encodes
  every value to `Data`, and on every write calls `CloudSync.pushIfSynced(key)`.
- iCloud sync is `NSUbiquitousKeyValueStore` mirroring, in
  [CloudSync.swift](../../Helpers/CloudSync.swift). A hard-coded `syncedKeys` set decides what roams:
  watchlist, saved dates, folders, folder membership, Movie Night provider ids, and the four
  TasteProfile keys. Local `UserDefaults` is the synchronous working copy; iCloud is a mirror.
- Deliberately **not** synced: `watchlistProviders` (region-specific), What's New snapshots/seen
  state, reminders, search history, Movie Coach cache, keyword cache.

**Assumption 1 in the prompt is false.** This has three consequences, all good:
the widget-snapshot-in-an-App-Group design still holds unchanged; there is no CloudKit import
notification to wait on in the onboarding gate (see §4.5); and adding a synced flag is a one-line
change to `syncedKeys` rather than a schema migration.

### Where everything lives

| Concern | File |
|---|---|
| Save / unsave / saved dates / per-title provider badge | [Helpers/WatchlistManager.swift](../../Helpers/WatchlistManager.swift) |
| Save call sites (only two) | [ContentDetailsView.swift:280](../../Screens/ContentDetails/ContentDetailsView.swift#L280), [GenericListView.swift:149](../../ViewComponents/Generic%20Views/GenericListView.swift#L149) |
| "I like this" taste signal | [Helpers/TasteProfile.swift](../../Helpers/TasteProfile.swift) — `TasteProfile.like(id:genreIDs:language:)` |
| Movie Night passes → implicit dislikes | `TasteProfile.recordPass(_:)` |
| Movie Night flow + match screen | [Screens/MovieNight/](../../Screens/MovieNight/) — `vm.topMatch` / `vm.matches` in `MovieNightViewModel` |
| User's streaming services | [Helpers/StreamingPreferences.swift](../../Helpers/StreamingPreferences.swift) — `providerIDs: [Int]`, synced |
| Provider catalogue for the picker | `ServiceInvocation.fetchProviders(screenType:region:)` → `MovieNightViewModel.availableProviders` (curated + ordered by `subscriptionProviders`) |
| Bell reminders | [Helpers/ReminderManager.swift](../../Helpers/ReminderManager.swift) + 3 UI sites (details nav bar, seasons tab, episodes list) |
| Notification permission | `ReminderManager.requestAuthorization()` — the single existing path |
| Notification tap → screen | `NotificationCenterDelegate` → [Helpers/DeepLinkRouter.swift](../../Helpers/DeepLinkRouter.swift) → `ContentView.applyDeepLink` |
| While You Were Away | [WatchlistChangeMonitor](../../Helpers/WatchlistChangeMonitor.swift) + [ChangeClassifier](../../Helpers/ChangeClassifier.swift) + [WatchlistChangeStore](../../Helpers/WatchlistChangeStore.swift) + `Screens/WhatsNew/` |
| Movie Coach availability | `MovieCoachService.availability` → `.ready / .unsupportedOS / .modelUnavailable`, [MovieCoachService.swift:163](../../Services/MovieCoachService.swift#L163) |
| Movie Coach UI (one entry point) | `MovieCoachView` inside `ContentDetailsView.movieCoachSection()` |
| Review prompt | [Helpers/ReviewRequestManager.swift](../../Helpers/ReviewRequestManager.swift) |
| Networking | `BaseNetworkService` → `ServiceInvocation` (one concrete class, `@unchecked Sendable`) |
| Region | `Locale.current.region?.identifier ?? "US"`, computed ad-hoc in 5 places |

### DI pattern, conventions, test harness

- **No DI container, no environment injection of services.** The pattern is:
  stateless logic and stores are `@MainActor enum` namespaces with `static` members;
  screens are MVVM triads (`XModel` / `XView` / `XViewModel: ObservableObject` held by `@StateObject`);
  network is injected only as a **default-argument parameter** —
  `func syncIfNeeded(using service: ServiceInvocation = ServiceInvocation(), …)`.
- Combine is already present (`ObservableObject` / `@Published` throughout). `@Observable` is not used.
- Pure-logic-plus-explicit-`now` is already the house style: `ChangeClassifier`,
  `WatchlistChangeStore` and `WhatsNewViewModel` all take `now: Date = Date()`. There is no
  `Clock`/`DateProvider` abstraction and introducing one would be a second pattern.
- Tests: `WatchnowTests/WhatsNewTests.swift`, XCTest, run against the test host's real
  `UserDefaults` with `WatchlistChangeStore.reset()` in `setUp`. Fixtures are hand-built value
  types with a frozen `fixedNow`. **Match this exactly.**
- Accessibility: `accessibilityLabel` is used consistently; `@Environment(\.accessibilityReduceMotion)`
  is honoured in Movie Night; `@Environment(\.dynamicTypeSize)` drives layout changes in
  `PrimaryActionRow`. All of this is real and must be carried into the new screens.

---

## 2. Surprises that change the prompt

These are the things worth reading before anything else. Each is logged in `DECISIONS.md`.

### S1 — The availability diff engine already exists. Phase 3 as written would build a second one.

`WatchlistChangeMonitor.syncIfNeeded` already runs every 12 hours, walks the whole watchlist in
batches of 3, and for **every** saved title fetches `/watch/providers` unconditionally. It diffs the
region's flatrate provider ids against a persisted `WatchlistSnapshot.providerIDs` and emits a
`.streamingAvailability` change. `WatchlistSnapshot` also already persists `nextEpisodeID`,
`nextEpisodeAirDate`, `lastEpisodeID`, `status` and `releaseDate` — i.e. exactly the episode data the
notification planner needs, already refreshed, already pruned when a title is unsaved.

It even contains an unused, deliberately-written policy stub:

> `// MARK: - Notifications (future)` … `static func shouldNotify(_ change:lastNotifiedAt:now:)`
> — *"Nothing calls a scheduler yet — this exists so a future release can notify without redesigning anything."*
> ([WatchlistChangeMonitor.swift:270](../../Helpers/WatchlistChangeMonitor.swift#L270))

**Recommendation: drop `AvailabilitySnapshot`, `AvailabilitySnapshotStore`, `AvailabilityRefresher`
and `AvailabilityDiffEngine` entirely.** Phase 3 becomes *"teach the existing monitor to run in the
background and hand its output to the planner"*, which is a fraction of the work and leaves one
source of truth instead of two. The prompt's own §"Do not add a second notification pipeline"
and "the new diff engine must become its single source of truth" point the same way — the diff
engine already exists, so the correct move is to make the *planner* consume it, not to rebuild it.

### S2 — There is no mark-as-watched feature. **Needs your decision.**

`PrimaryActionRow` has three actions: *Watch Later / Saved*, *Trailer*, *I like this*. The file's own
header comment mentions "Saved / Watched" but no watched state exists anywhere — no store, no key,
no UI. Three release requirements depend on it:

- "`requestReview` … on the third mark-as-watched"
- widget: "Never show a watched title"
- "fires only when a tracked, **unwatched** title becomes streamable"

Options, in order of my preference:

1. **Build a minimal Watched toggle** (one synced `Set<Int>`, a fourth pill or a swipe action in the
   watchlist grid, "Watched" section/filter). ~½ a phase of work. It makes all three requirements
   honest, is itself a retention mechanic (a tracker you can close the loop in is one you return to),
   and it is the thing a watchlist app is most obviously missing.
2. **Substitute proxies** and ship without it: review trigger becomes Movie Night match + the
   existing 3-saves trigger; the widget's "not watched" filter becomes "not watched" ≡ "still saved"
   (unsaving already is the app's only completion signal today).
3. Defer the whole widget/review "watched" language to v2.2.

I recommend (1), as a **new Phase 1.5**, and have costed the plan below both ways.

### S3 — There is no Settings screen at all.

Four tabs: Movies, Series, Search, Watchlist. No settings sheet, no preferences row, nowhere for
"Episode alerts" / "Now streaming alerts" / "notifications are off — here's how to turn them on".
Proposal: a new `SettingsView` sheet presented from a gear in the **Watchlist** tab toolbar (the
same toolbar slot the DEBUG hammer already occupies), containing: alert toggles, the notification-
permission row, streaming services (currently only reachable via Movie Night setup), the iCloud
sync caption (`SyncStatus` is already built for this and unused outside Movie Night), TMDB/JustWatch
attribution, and — in DEBUG — the developer menu Phase 2 calls for.

### S4 — "Data Not Collected" is not true today, and the prompt's constraint needs restating.

The app links **GoogleMobileAds** and **GoogleUserMessagingPlatform**, starts the SDK
unconditionally at launch, presents a UMP/GDPR consent form, and shows banner, native and
interstitial ads. `PrivacyInfo.xcprivacy` declares no collected data types — correct for the
*app's own* manifest, since SDKs ship their own — but the **App Store privacy label** must cover SDK
collection too, so "Data Not Collected" is inconsistent with a shipping AdMob integration.

This is App Store Connect metadata and explicitly out of Claude Code's scope, so nothing in this
plan touches it. What I will hold myself to is the honest version of the constraint:
**this release adds no new data collection, no new third-party SDK, and no new network destination.**
Flagging it because the prompt leans on the privacy label in both the Context and the Constraints,
and in the Appendix's Featuring Nomination pitch.

### S5 — The onboarding/Coach finish sequence is impossible as specified.

`MovieCoachService.minimumWatchlistSize = 5`: Coach deliberately says nothing until the user has
saved 5 titles, because below that "it would be guessing dressed up as advice". Onboarding step 3
asks for **three** saves. So "onboarding ends by showing a Coach verdict on the first saved title"
can never fire on a fresh install. Pick one: raise step 3 to five saves, lower
`minimumWatchlistSize`, or count step 2's five *loved* titles toward Coach's history. I recommend
the last — the loved picks are a stronger taste signal than saves, and it needs no UX change.

### S6 — The bell only exists for *unreleased* titles.

`navBarTrailingView` renders the bell only `if detailsViewModel.futureReleaseDate != nil`. A
currently-airing series — precisely the case "new episode" alerts target — shows no bell at all.
"The existing bell can become the per-title control" therefore requires extending the bell's
visibility to any series with a `next_episode_to_air`. Small, but it is a behaviour change to an
existing screen and worth naming.

### S7 — Other assumption corrections

| # | Prompt assumption | Reality |
|---|---|---|
| 2 | TMDB `/watch/providers`, region determined in-app | **True.** `Locale.current.region ?? "US"`, computed in 5 places — worth centralising while we're here |
| 3 | Bell reminders use `UNUserNotificationCenter`, one permission path to extend | **True.** `ReminderManager.requestAuthorization()` |
| 4 | A services selection exists and is reusable | **True.** `StreamingPreferences.providerIDs`, already synced |
| 5 | "I like this" is reusable by `TasteSeeder` | **True.** `TasteProfile.like(id:genreIDs:language:)` takes loose pieces, no `Result` needed |
| 6 | No deep-link routing yet | **Half false.** `DeepLinkRouter` + `DeepLink{id, mediaType}` exist for notification taps. No **URL scheme** — that part is still in scope, and `DeepLink` must grow a case for the widget's "Movie Night" secondary action |
| 7 | Test coverage minimal, may need a target | **A target exists** (`WatchnowTests`, in the scheme, XCTest). One file, ~covering What's New. Extend it |
| 8 | Swift 6 / strict concurrency | **True.** Swift 6 language mode. Note the existing `@unchecked Sendable` escape hatches on the network classes |

Also worth knowing:

- **`ReviewRequestManager` already exists** and fires on 3 watchlist saves + 2 days + once per
  version. The prompt's triggers are strictly *narrower* (Movie Night match or 3rd watched, once per
  120 days). Given the store has zero ratings, narrowing could make that worse, not better —
  I'd **keep the existing save-based trigger as a third path** and add the two new ones. Flagged.
- **Movie Coach gating is already correct.** One entry point, `MovieCoachView` returns `EmptyView()`
  unless `MovieCoachService.isReady`. Phase 4's "migrate every entry point / remove Coach where
  unavailable" is close to a no-op — I'll verify and move on rather than manufacture work.
- **DEBUG builds fire every reminder ~3s after scheduling**, ignoring the date
  ([ReminderManager.swift:96](../../Helpers/ReminderManager.swift#L96)). Any reconcile-against-pending
  logic will look bizarre in Debug. The new scheduler must **not** inherit this hack; it gets its own
  DEBUG affordance instead.
- **`aps-environment` and CloudKit entitlements are present but unused** (KVS is the only sync).
  Harmless, but they invite the wrong conclusion about the architecture. Propose removing.
- **No String Catalog. Every user-facing string is a hard-coded Swift literal.** See §5.
- **Ads and onboarding will race at launch.** `WatchnowApp` presents the UMP consent form in a
  `.task` on `ContentView`. Onboarding fires on the same launch. Ordering must be explicit:
  consent form first (it is a legal precondition for personalised ads), onboarding second.
- **`MobileAds`/interstitials**: `InterstitialAdManager.presentIfAllowed()` fires on the Movie Night
  results screen — the same screen the new "Movie Night match" review trigger targets. Two modals,
  one moment. The review trigger must yield to the interstitial.

---

## 3. Proposed modules (named to the codebase's grain)

The house pattern is `@MainActor enum` namespaces in `Helpers/`, MVVM triads in `Screens/`.
Names below avoid the prompt's generic `*Service` vocabulary where the codebase already has a
stronger local word (`Manager`, `Store`, `Preferences`, `Monitor`, `Classifier`).

```
Helpers/
  AlertPreferences.swift       enum · global toggles + per-title opt-outs   [P1]
  AutoAlertPolicy.swift        pure · save event + toggles → alert decision [P1]
  NotificationPermission.swift enum · explainer → ReminderManager.request…  [P1]
  WatchedStore.swift           enum · synced Set<Int> + "watched at"        [P1.5, if S2 = option 1]
  AlertPlanner.swift           pure · (snapshots, changes, pending, now,
                                       caps) → [PlannedAlert] ≤ 64          [P2]
  AlertScheduler.swift         shell · idempotent reconcile vs pending      [P2]
  BackgroundRefresh.swift      enum · BGTaskScheduler registration +
                               the pipeline; also the foreground path       [P2]
  OnboardingGate.swift         pure · (completed, count, iCloud state) →
                                       show / wait / skip                   [P4]
  WidgetSnapshotWriter.swift   shell · JSON + poster cache → App Group      [P5]
  Region.swift                 the one definition of the TMDB region        [P2, tidy-up]

Screens/Settings/
  SettingsView.swift           sheet from the Watchlist toolbar             [P1]
  SettingsDebugSection.swift   #if DEBUG developer menu                     [P2]

Screens/Onboarding/
  OnboardingModel.swift        step enum + selection state                  [P4]
  OnboardingViewModel.swift    ObservableObject, owns the 3 steps           [P4]
  OnboardingView.swift         container + finish sequence                  [P4]
  OnboardingServicesStep.swift / OnboardingLovedStep.swift /
  OnboardingSaveStep.swift                                                  [P4]

Shared/                        (membership in BOTH targets)
  WidgetSnapshot.swift         Codable value type + App Group paths         [P5]

WatchnowWidget/                (new extension target)
  WatchnowWidgetBundle.swift / TonightsPickProvider.swift /
  TonightsPickSmallView.swift / TonightsPickMediumView.swift               [P5]

WatchnowTests/
  AlertPlannerTests.swift · OnboardingGateTests.swift ·
  WidgetPickTests.swift · AutoAlertPolicyTests.swift
```

### Design choices worth arguing about now

**No `FollowService` / follow flags.** Auto-follow is on by default for every save, so a stored
follow flag would be a copy of the watchlist with a sync-merge hazard (device A saves and sets a
flag; device B has the title from an older sync and no flag — which wins?). Instead:
*followed ≡ in the watchlist AND not in the opt-out set.* `AlertPreferences` stores only
`alertsOptedOut: Set<Int>` plus the two global bools. `WatchlistManager.removeFromWatchList`
already has the hook to forget per-title side-tables; the opt-out joins `addedDates`/`providers`
there. Smaller, synced trivially, and there is no state to migrate.

**No `Clock` / `DateProvider` protocol.** The codebase's existing pure functions take
`now: Date = Date()` as a parameter and are fully tested that way. Adding a clock protocol would be
the second pattern the prompt forbids. Same reasoning for `NotificationCenterClient`: the planner is
pure and takes `[UNNotificationRequest]`-derived value types, so the only thing left to fake is
`AlertScheduler`'s three calls — a protocol there earns its keep, a clock does not.

**The widget reads `WatchlistManager.providers`, not a new availability store.** That table already
holds `SavedProvider {id, name, logoPath, kind, capturedAt}` per saved title and is refreshed twice
a day by the change monitor. "Streamable on a service you have" = `kind == .stream` ∧
`StreamingPreferences.providerIDs.contains(id)`. Zero new fetching for the widget snapshot.

---

## 4. Revised phase plan

Each phase still ends in a stop. Deltas from the prompt are called out.

### Phase 0 — Discovery *(this document)* ✅
`PLAN.md` + `DECISIONS.md`. No code. **Stop for review of §2 in particular.**

### Phase 1 — Alert preferences, permission, Settings
- `AlertPreferences` (2 global toggles + per-title opt-out set; toggles and opt-outs added to
  `CloudSync.syncedKeys`), `AutoAlertPolicy` (pure).
- `NotificationPermission`: one-screen explainer → `ReminderManager.requestAuthorization()` →
  outcome. Never at launch. Denial is silent and never re-prompted.
- New `SettingsView` sheet (S3), wired to the Watchlist toolbar; hosts the toggles, the permission
  row, streaming services, sync caption, attributions.
- Extend the bell to airing series (S6) and make it the per-title opt-out control.
- Hook the first-ever save to the explainer.
- Tests: `AutoAlertPolicy`, opt-out round-trip through `CloudSync`.
- Existing bell reminders keep working unchanged. **Stop.**

### Phase 1.5 — Mark as watched *(confirmed in scope — D-6)*
`WatchedStore` (synced), a Watched control on the details screen + watchlist grid, a watched filter,
exclusion from Movie Night decks. Tests for the store and the filter. **Stop.**

### Phase 2 — Alert planning + background refresh
- `AlertPlanner` (pure): inputs are the existing `WatchlistSnapshot`s (which already carry
  `nextEpisodeAirDate`), the pending `reminder.*` identifiers, `now`, and the caps. Output is
  `[PlannedAlert]` ≤ 64, ordered, quiet-hours-batched, deduped against manual reminders.
  New identifiers are namespaced `auto.episode.*` / `auto.streaming.*` so manual `reminder.*`
  requests are never touched.
- `AlertScheduler` (shell): idempotent reconcile — add missing, remove stale `auto.*` only.
- `BackgroundRefresh`: register a `BGAppRefreshTask`, add `UIBackgroundModes` +
  `BGTaskSchedulerPermittedIdentifiers` to `Info.plist`, run `WatchlistChangeMonitor.syncIfNeeded`
  with a time budget, always `setTaskCompleted` + reschedule. Same pipeline on cold launch.
- DEBUG menu in Settings: run refresh now · fire sample alert · reset onboarding · show widget
  snapshot · reset review throttle. Must sidestep `ReminderManager`'s 3-second DEBUG trigger.
- Tests: the planner, thoroughly — 64 limit, per-title/day cap, 3/day cap, 22:00–09:00 batching to a
  09:00 digest, manual-reminder precedence, trim ordering, idempotence of two consecutive plans.
- **Stop.**

### Phase 3 — "Now streaming" alerts *(scope cut — see S1)*
- **No new availability modules.** Instead: give `WatchlistChangeMonitor` a background entry point
  with a batch cap (~40 titles, oldest `lastCheckedAt` first — it currently walks the whole list),
  and feed its `.streamingAvailability` changes into `AlertPlanner`.
- Move `WatchlistChangeMonitor.shouldNotify` into `AlertPlanner` (it is policy, and policy now lives
  in the planner) with the "only on a service the user has, only unwatched" narrowing.
- Digest copy when several land in one run.
- While You Were Away keeps consuming the same store — **already the single source of truth**;
  nothing to rewire, one thing to verify: a change that produced a notification must not also lead
  the next briefing as news.
- Tests: digest batching, service-filtering, notify-once-per-change.
- **Stop.**

### Phase 4 — Onboarding + Coach gating
- Verify Coach gating (expected: already correct; `CoachAvailability` becomes a thin alias over
  `MovieCoachService.availability` only if it earns its keep — otherwise no new type).
- `OnboardingGate` (pure). The iCloud wait is **KVS-shaped, not CloudKit-shaped** (S7/#1): when
  `CloudSync.isAvailable`, wait up to 3s for `CloudSync.didMergeRemoteChanges` carrying `watchlist`,
  or a non-empty watchlist, behind a light "Restoring your watchlist…" indicator; when not signed
  into iCloud, skip the wait entirely.
- Three steps, all skippable; `TasteSeeder` → `TasteProfile.like(...)`; finish on Watchlist.
- Coach verdict at finish — resolve S5 first.
- Ordering vs the UMP consent form made explicit (S7).
- Watchlist empty-state CTA rewrite.
- Tests: gate (including the restore-wait branches), seeder mapping. Manual VoiceOver pass.
- **Stop.**

### Phase 5 — Widget · **CUT**

Dropped on 2026-09-13 by the dev, after weighing it against the other four
mechanisms (see D-51). A widget only reaches users who perform a five-step
gesture they don't know exists, it was the only phase needing a new target and
new entitlements, and its effect could never be separated from the rest in App
Store Connect. Revisit for v2.2 once the four shipped mechanisms have been
measured — and if it returns, it returns with an in-app nudge, because a widget
nobody adds is worse than no widget.

### Phase 6 — Review prompt, polish, release
- Modify `ReviewRequestManager` (do **not** add a coordinator beside it): 120-day throttle,
  Movie Night match + 3rd watched triggers, never first session / first 48h, yield to the Movie
  Night interstitial. Recommend keeping the existing save-based path as a third trigger (S7).
- Accessibility pass; confirm no new network destinations; privacy manifest unchanged (no new
  data types — `NSPrivacyAccessedAPICategoryUserDefaults` already declared).
- `RELEASE_NOTES.md` in the app's What's New voice + the QA checklist from the prompt.
- **Stop.**

---

## 5. Cross-cutting decisions — resolved 2026-09-13

| # | Question | Resolution |
|---|---|---|
| S1 / D-3 | Build the Availability* modules, or extend the existing pipeline? | **Extend.** Phase 3 rescoped; no parallel diff engine |
| S2 / D-6 | Mark-as-watched: build, substitute, or defer? | **Build it**, as Phase 1.5 |
| S5 / D-9 | Coach's 5-title floor vs onboarding's 3 saves | **The five loved picks count** toward Coach's history |
| D-11 | Review triggers: replace or union? | **Union** — Movie Night match + third watched + the existing save trigger, one 120-day throttle |
| D-13 | Localization | **Default taken:** one `Localizable.xcstrings` + `SWIFT_EMIT_LOC_STRINGS = YES`, app-wide auto-extraction, new screens keep writing plain literals. Not explicitly asked — say so before Phase 1 to change it |
| D-15 | Where Settings lives | **Default taken:** a sheet from a gear in the Watchlist toolbar, beside the existing DEBUG hammer. Same caveat |

Still open, but they are Phase-2 and Phase-4 details rather than blockers, and carry my
recommendation in `DECISIONS.md`: D-4 (opt-out set instead of follow flags), D-5 (no clock
protocol), D-7 (`auto.*` identifier namespace), D-8 (KVS-shaped restore wait), D-10 (bell on airing
series), D-16 (consent form before onboarding), D-18 (remove the unused push/CloudKit entitlements).

## 6. Manual steps only you can do (portal / Xcode)

- Create App Group `group.k.christopoulos.Watchnow` and enable it on **both** targets (Phase 5).
- Add the `WatchnowWidget` extension target (Phase 5).
- Confirm Background Modes capability when Phase 2 adds `BGTaskSchedulerPermittedIdentifiers`.
- App Store Connect privacy-label review in light of S4 (not code, but it belongs on the list).

## 7. Build & verification baseline

```
xcodebuild -project Watchnow.xcodeproj -scheme Watchnow \
  -destination 'generic/platform=iOS Simulator' build
xcodebuild -project Watchnow.xcodeproj -scheme Watchnow \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```
Run from the **repo root** (`Desktop/MyProjects`), not from `Watchnow/`.

Every new `.swift` file needs explicit `project.pbxproj` entries (`PBXBuildFile`,
`PBXFileReference`, the group's `children`, and the target's `Sources` phase) — this project has no
file-system-synchronized groups, so a file added on disk alone compiles to nothing and fails
silently at runtime.

**Baseline verified 2026-09-13:** `xcodebuild … build` exits 0 with **three** pre-existing
first-party warnings (plus GoogleMobileAds umbrella-header noise from the SDK):

| File | Warning |
|---|---|
| `WatchnowApp.swift:79` | consider using asynchronous alternative function (`ConsentForm.loadAndPresentIfRequired`) |
| `ReviewRequestManager.swift:50` | no 'async' operations occur within 'await' expression |
| `BannerAdView.swift:69` | `currentOrientationAnchoredAdaptiveBanner(width:)` is deprecated |

"Zero new warnings" is measured against this list. The `ReviewRequestManager` one is free to fix in
Phase 6, since that file is being rewritten anyway.
