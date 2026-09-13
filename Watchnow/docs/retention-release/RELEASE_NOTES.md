# Watchnow 2.1 — release notes

## App Store "What's New" (user-facing)

Written in the voice of the existing What's New copy: plain, specific, no
feature-list padding.

---

**Watchnow now tells you when it's time.**

Save something and we'll let you know the day a new episode airs, or the day
it lands on a service you actually have. Two kinds of alert, never more than
three a day, nothing after 10pm — and you can switch either off, or mute a
single title, whenever you like.

**New here? We'll set you up in three taps.**
Pick your streaming services, tap a few things you've loved, and start your
watchlist with three picks chosen from your taste. Your first session now
ends with a watchlist worth coming back to.

**Mark things watched.**
Finished something? Mark it. Watched titles step aside in your watchlist,
stop turning up in Movie Night, and stop sending you alerts.

**Also in this release**
- Your streaming services now live in Settings, not just Movie Night
- Alerts, sync status and the data credits all have a home under the new gear
- Movie Coach starts sooner — the titles you like count towards it too

---

## Internal summary

Everything in this release is a return trigger. The problem it addresses is
visible in App Store Connect: opted-in active devices have equalled that
month's installs every month since launch (May 21/18, Jun 19/17, Jul 25/27,
Aug 27/26). Almost nobody comes back.

Four mechanisms shipped:

| Mechanism | Reaches | Phase |
|---|---|---|
| Episode alerts | Anyone who saves a series and grants notifications | 2 |
| Now-streaming alerts | Anyone who saves anything and picks services | 3 |
| Onboarding | 100% of new installs | 4 |
| Review prompt | Anyone hitting one of three payoff moments | 6 |

A fifth — the "Tonight's Pick" home-screen widget — was **cut**. Its reach is
gated on a five-step gesture most users never perform, and it was the only
part of the release needing new targets and entitlements. Revisit in v2.2 once
the four above have been measured.

### How to tell whether it worked

App Store Connect → Analytics → **Active Devices vs Installations, Weeks
view**. Success is the Active Devices line pulling away above Installations.
There is no in-app telemetry and there will be none, so this is the only
signal. Give it two full months before reading anything into it — alerts only
fire when something actually airs or lands.

### What changed under the hood

- No new third-party dependencies, no new network destinations. The four hosts
  the app talks to (`api.themoviedb.org`, `image.tmdb.org`, `themoviedb.org`,
  `youtube.com`) are unchanged.
- `PrivacyInfo.xcprivacy` needs no edit: no new data types are collected, and
  `NSPrivacyAccessedAPICategoryUserDefaults` was already declared.
- Availability detection was **not** rebuilt. The What's New pipeline has been
  diffing `/watch/providers` twice a day since v2.0; alerts now read the same
  store. There is one detector in this app.
- New in `Info.plist`: `BGTaskSchedulerPermittedIdentifiers` and
  `UIBackgroundModes: fetch`.
- `Localizable.xcstrings` added with `SWIFT_EMIT_LOC_STRINGS = YES`, so every
  existing `Text("…")` is now extractable. English only; no translation yet.

### Before submitting

1. Open `Localizable.xcstrings` in Xcode once so it populates from the 302
   extracted string tables, then commit it.
2. Confirm Background App Refresh appears under the target's capabilities.
3. Bump `MARKETING_VERSION` to 2.1.
4. Re-check the App Store privacy label against the AdMob integration — see
   DECISIONS D-12. Not changed by this release, but not obviously right either.
