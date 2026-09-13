//
//  NotificationExplainerView.swift
//  Watchnow
//
//  The screen that earns the system prompt.
//
//  iOS gives an app exactly one chance to ask for notification permission,
//  and a prompt that arrives cold is mostly declined. So this sheet goes
//  first, says plainly what the two alerts are, and only then hands over to
//  iOS — and if the user says "Not now" here, the system prompt is never
//  spent at all. It can be granted later from Settings.
//
//  Presented by `ContentView` after the first save; `NotificationPermission`
//  owns the when, this owns the what.
//

import SwiftUI

struct NotificationExplainerView: View {

    /// The user accepted — the caller asks iOS.
    let onAllow: () -> Void
    /// The user declined — the caller records it and stays quiet.
    let onDecline: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Centred while it fits, scrollable once it doesn't. Pinning
            // this to the top left a dead half-screen between the copy and
            // the buttons at default text sizes; letting it float keeps the
            // sheet balanced there and still reachable at 200%.
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        reasons
                        reassurance
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: proxy.size.height, alignment: .center)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            actions
        }
        .background(Color(.background))
        .opacity(appeared ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: AppMotion.emphasis), value: appeared)
        .onAppear { appeared = true }
        .interactiveDismissDisabled()
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "bell.badge")
                .appFont(34, weight: .semibold, relativeTo: .largeTitle)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("Never miss the moment")
                .appFont(28, weight: .bold, relativeTo: .title)

            Text("Watchnow can tell you the day something you saved is finally watchable.")
                .appFont(16, relativeTo: .body)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var reasons: some View {
        VStack(alignment: .leading, spacing: 14) {
            reason(icon: "tv",
                   title: "New episodes",
                   detail: "The day the next episode of a series you saved airs.")
            reason(icon: "play.tv.fill",
                   title: "Now streaming",
                   detail: "When a saved title lands on a service you have.")
        }
    }

    private func reason(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .appFont(17, weight: .semibold, relativeTo: .body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .appFont(16, weight: .semibold, relativeTo: .body)
                Text(detail)
                    .appFont(14, relativeTo: .subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The honest part, and the reason this screen is short: two kinds of
    /// alert, a handful a week at most, and every one of them switchable.
    private var reassurance: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.raised")
                .appFont(13, weight: .medium, relativeTo: .footnote)
                .accessibilityHidden(true)
            Text("Only these two, only for titles you saved, and you can switch either off in Settings at any time.")
                .appFont(13, relativeTo: .footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.secondary)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: onAllow) {
                Text("Turn on alerts")
                    .appFont(17, weight: .semibold, relativeTo: .body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: AppTouch.minTarget)
                    .background {
                        AppRadius.shape(AppRadius.panel).fill(Color.accentColor)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Asks iOS for permission to send you alerts")

            Button(action: onDecline) {
                Text("Not now")
                    .appFont(16, weight: .medium, relativeTo: .body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: AppTouch.minTarget)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(Color(.background))
    }
}
