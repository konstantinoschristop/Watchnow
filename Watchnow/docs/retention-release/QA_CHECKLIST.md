# Watchnow 2.1 — QA checklist

Ordered by how much damage a failure would do. Everything marked **device**
cannot be checked on a simulator and must be done on hardware.

---

## 1. Second-device restore — the one that matters most

Showing a setup flow to someone with a four-year watchlist is the worst
outcome in this release.

- [ ] **device** Sign in to iCloud, use the app until the watchlist has titles.
- [ ] **device** Delete the app. Reinstall. Launch.
- [ ] Onboarding must **not** appear. A brief "Restoring your watchlist…"
      caption may appear at the bottom; the watchlist then fills.
- [ ] **device** Install on a second device signed into the same account —
      same expectation.
- [ ] Settings → alert toggles and muted titles should match the first device.

*Simulator note:* `simctl uninstall` leaves the key-value store behind, so the
app "restores" itself and the gate skips. To see a genuine first run you must
also delete
`~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Containers/Data/InternalDaemon/*/com.apple.kvs`.
And with no iCloud account, the three-second restore wait never runs at all.

## 2. Fresh install

- [ ] First launch shows the consent form (where required) and **then**
      onboarding — never both at once.
- [ ] Step 1: services load and select. Continue is disabled until one is on.
- [ ] Step 2: 30 titles, films and shows mixed. "0 of 5" counts up.
- [ ] Step 3: picks visibly reflect step 2, not generic trending.
- [ ] Skipping all three steps still lands on the watchlist with the
      "Nothing saved yet" state and a working **Browse Trending** button.
- [ ] Finish lands on the **Watchlist** tab with the three covers visible.
- [ ] Relaunch: onboarding does not reappear.
- [ ] Debug build: Settings → Developer → **Reset onboarding**, relaunch,
      confirm it runs again.

## 3. Notification permission

- [ ] The prompt is **never** shown at launch.
- [ ] First save (or end of onboarding) shows the explainer sheet first.
- [ ] "Not now" → no system prompt, and the explainer never returns.
- [ ] "Turn on alerts" → system prompt → Allow.
- [ ] Deny at the system prompt: nothing re-prompts, and Settings shows
      "Open iOS Settings" with an honest footer.
- [ ] Turn notifications off in iOS Settings, reopen: the footer updates.

## 4. Alerts

- [ ] Save a currently-airing series. Debug menu → **Run refresh + plan now**
      → **Show planned alerts** shows an entry at 18:00 on the air date.
- [ ] **Show pending notifications** shows it as `auto.episode.<id>.<date>`.
- [ ] Run the pass again: `Reconciled: +0 / −0`. Running twice must change
      nothing.
- [ ] Settings → Episode alerts off → run again → `−1`, and the pending list
      empties.
- [ ] Mute a single title with the bell on its details page → same effect for
      that title only.
- [ ] Manual bell reminders on unreleased titles still work and are **never**
      removed by a reconcile.
- [ ] **device** Background refresh: Xcode → Debug → Simulate Background Fetch.
      The app must not crash and must reschedule.
- [ ] **device** Tap a delivered alert → opens the right title.

*Debug-build caveat:* manual bell reminders fire ~3 seconds after being set
regardless of date, so their dates in the debug list are not real ones. The
automatic alerts do not do this.

## 5. Now streaming

- [ ] Settings → pick at least one service (with none picked, no
      now-streaming alert can fire — this is intended).
- [ ] Debug menu → plan line reads `N dated · M streaming → …`.
- [ ] A single change reads "{Title} is now on {Service}".
- [ ] Two or more in one run collapse to one digest: "{n} titles from your
      watchlist are new on your services".
- [ ] The same change must not alert twice. Run the pass repeatedly.
- [ ] Mark a title watched → it stops producing now-streaming alerts.

## 6. Watched

- [ ] Details screen: "Mark as watched" → "Watched", persists across launches.
- [ ] Watchlist grid: long-press → Mark as watched → cover dims, checkmark
      appears.
- [ ] Watched titles are excluded from the Movie Night deck.
- [ ] Unsaving a title forgets that it was watched.
- [ ] **device** The state appears on a second device.

## 7. Movie Coach

- [ ] **device, iOS 26 + Apple Intelligence iPhone**: onboarding's finish
      screen shows a real Coach verdict on the first saved title.
- [ ] **device, any older or ineligible iPhone**: no Coach anywhere — not on
      the finish screen, not on a details screen, not greyed out, not
      "coming soon".
- [ ] With fewer than five titles known, the warm-up hint counts saves **and**
      likes ("Save or like N more…").

## 8. Review prompt

Hard to test live — the throttle is four months. Check the policy behaviour
via the unit tests, then confirm the wiring by hand:

- [ ] It never appears in the first session.
- [ ] Movie Night → match → tap "View details": the Movie Night interstitial
      must resolve first; the review sheet must not stack on top of it.
- [ ] After one prompt, no further prompt for 120 days.
- [ ] Upgrading from 2.0 having already been prompted must not prompt again
      immediately.

## 9. Accessibility

- [ ] VoiceOver through all three onboarding steps: every chip and poster is
      one element that announces its name and selected state.
- [ ] VoiceOver on the watchlist: a watched cover announces "watched".
- [ ] VoiceOver on the details bell: announces mute state, and the hint says
      what will actually be sent.
- [ ] Dynamic Type at AX3 and AX5: onboarding's service chips become
      full-width rows, nothing clips off the right edge, the header scrolls
      away, and the footer stays reachable.
- [ ] Reduce Motion on: no spring animations in onboarding, the explainer, or
      the watched toggles.
- [ ] Dark mode across all new screens.

## 10. Regression — nothing from v2.0 broke

- [ ] "While You Were Away" still appears after a genuine absence.
- [ ] Folders, sort, and the layout toggle behave as before.
- [ ] Movie Night plays through to a match.
- [ ] Ads still render (banner, native, interstitial) in a Release build.
- [ ] iCloud sync of watchlist, folders and taste still works.
