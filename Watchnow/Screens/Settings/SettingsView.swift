//
//  SettingsView.swift
//  Watchnow
//
//  The app's first settings screen. Presented as a sheet from the Watchlist
//  tab, because that is where the things it governs live.
//
//  Built as a plain `Form` rather than from the app's card vocabulary on
//  purpose: a settings list is a system-shaped screen, and the system shape
//  is already correct at every Dynamic Type size and under VoiceOver without
//  a line of layout code. The design tokens exist for content surfaces —
//  posters, briefings, swipe decks — and this is not one.
//
//  It gathers three things that until now had nowhere to live: the new alert
//  switches, the iCloud sync state, and the data-source attributions TMDB's
//  terms require.
//

import SwiftUI

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var permission = NotificationPermission.shared
    @ObservedObject private var syncStatus = SyncStatus.shared

    /// Mirrors of the persisted switches. `@UserDefault` is not observable,
    /// so the view holds the working copy and writes through on change —
    /// the same shape as `isReminderOn` and `isLiked` on the details screen.
    @State private var episodeAlerts = true
    @State private var streamingAlerts = true

    var body: some View {
        NavigationStack {
            Form {
                alertsSection
                syncSection
                aboutSection
                #if DEBUG
                SettingsDebugSection()
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            episodeAlerts = AlertPreferences.episodeAlertsEnabled
            streamingAlerts = AlertPreferences.streamingAlertsEnabled
            await permission.refreshStatus()
        }
        .onChange(of: episodeAlerts) { _, value in
            AlertPreferences.episodeAlertsEnabled = value
        }
        .onChange(of: streamingAlerts) { _, value in
            AlertPreferences.streamingAlertsEnabled = value
        }
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        Section {
            Toggle("Episode alerts", isOn: $episodeAlerts)
                .accessibilityHint("Tells you the day the next episode of a saved series airs")

            Toggle("Now streaming alerts", isOn: $streamingAlerts)
                .accessibilityHint("Tells you when a saved title lands on a service you have")

            permissionRow
        } header: {
            Text("Alerts")
        } footer: {
            Text(alertsFooter)
        }
    }

    /// Only shown when iOS is the thing standing in the way. When permission
    /// is granted the switches above are the whole story, and a row saying
    /// "notifications: on" would be noise.
    @ViewBuilder
    private var permissionRow: some View {
        if !permission.isAuthorized {
            Button {
                Task { await permission.requestFromSettings() }
            } label: {
                HStack {
                    Text(permission.canStillAsk ? "Turn on notifications" : "Open iOS Settings")
                        .foregroundStyle(Color.accentColor)
                    Spacer(minLength: 0)
                    Image(systemName: permission.canStillAsk ? "bell.badge" : "arrow.up.right.square")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var alertsFooter: String {
        if permission.isAuthorized {
            return "Alerts cover titles you have saved. Mute a single title with the bell on its page."
        }
        if permission.canStillAsk {
            return "Notifications are off for Watchnow, so nothing will be delivered yet."
        }
        return "Notifications are turned off for Watchnow in iOS Settings, so nothing will be delivered."
    }

    // MARK: - Sync

    @ViewBuilder
    private var syncSection: some View {
        if syncStatus.isAvailable {
            Section {
                HStack {
                    Label("iCloud", systemImage: "checkmark.icloud")
                    Spacer(minLength: 0)
                    Text(syncCaption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text("Sync")
            } footer: {
                Text("Your watchlist, folders, taste and alert settings follow you to your other devices.")
            }
        }
    }

    private var syncCaption: String {
        guard let date = syncStatus.lastSyncedAt else { return "Synced" }
        if Date().timeIntervalSince(date) < 5 { return "Just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer(minLength: 0)
                Text(versionString)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        } header: {
            Text("About")
        } footer: {
            // TMDB's terms require this wording in-app, and their licensing
            // of the availability data requires the JustWatch credit beside
            // it. Both already appear on the details screen; this is the
            // app-level home for them.
            Text("This product uses the TMDB API but is not endorsed or certified by TMDB. Streaming availability provided by JustWatch.")
        }
    }

    private var versionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return short
    }
}
