//
//  SeasonsDetailsTabView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 15/8/22.
//
//  Bottom sheet showing all episodes for a selected season.
//
//  Layout:
//    - Sheet header: season name + episode count
//    - Horizontally-scrollable pill tabs, one per season — purple tint,
//      animated capsule highlight. ScrollViewReader keeps the selected
//      pill centred in view whenever the selection changes (or on appear).
//    - Episode list (or appropriate empty/loading state)
//

import SwiftUI
import AlertToast

struct SeasonsDetailsTabView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    @StateObject private var episodesViewModel: EpisodesViewModel
    let seasons: [Season]
    let seriesID: Int
    let seriesName: String
    @Binding var selectedSeason: Season
    @Namespace private var pillNamespace
    @State private var seasonReminderOn = false
    @State private var showReminderToast = false
    @State private var showNotificationSettingsAlert = false

    init(seasons: [Season],
         selectedSeason: Binding<Season>,
         seriesID: Int,
         seriesName: String) {

        self.seasons = seasons
        self.seriesID = seriesID
        self.seriesName = seriesName
        _selectedSeason = selectedSeason
        _episodesViewModel = StateObject(wrappedValue: EpisodesViewModel(service: ServiceInvocation(),
                                                                         seriesID: seriesID))
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            seasonTabs
            Divider()
            episodeContent
        }
        .background(Color(.background))
        .task(id: selectedSeason) {
            await episodesViewModel.getEpisodes(seasonNumber: selectedSeason.season_number ?? 0)
            await ReminderManager.reconcileWithSystem()
            syncReminderState()
        }
        .onChange(of: selectedSeason) { _, _ in
            syncReminderState()
        }
        .toast(isPresenting: $showReminderToast, alert: {
            seasonReminderOn ?
            AlertToast(displayMode: .alert, type: .complete(.green), title: "Reminder Set") :
            AlertToast(displayMode: .alert, type: .error(.red), title: "Reminder Removed")
        })
        .alert("Notifications are off",
               isPresented: $showNotificationSettingsAlert) {
            Button("Open Settings") { ReminderManager.openNotificationSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable notifications for Watchnow in Settings to set season reminders.")
        }
    }

    // MARK: - Sheet Header

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(selectedSeason.name ?? "Season")
                .appFont(20, weight: .bold, relativeTo: .title3)
                .foregroundStyle(.primary)
                .animation(reduceMotion ? nil : .easeInOut(duration: AppMotion.quick), value: selectedSeason)

            // Prefer live episode count from the fetched response; fall back
            // to the season model's own count while loading.
            let count = episodesViewModel.episodes?.episodes?.count
                        ?? selectedSeason.episode_count
                        ?? 0
            Text("\(count) Episodes")
                .appFont(13, relativeTo: .footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 14)
    }

    // MARK: - Season Pill Tabs

    private var seasonTabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(seasons, id: \.self) { season in
                        seasonPill(season, proxy: proxy)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            // Scroll to the active tab on first appear and on every change.
            .onAppear {
                proxy.scrollTo(selectedSeason, anchor: .center)
            }
            .onChange(of: selectedSeason) { _, season in
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                    proxy.scrollTo(season, anchor: .center)
                }
            }
            .sensoryFeedback(.selection, trigger: selectedSeason)
        }
    }

    @ViewBuilder
    private func seasonPill(_ season: Season, proxy: ScrollViewProxy) -> some View {
        let isSelected = selectedSeason == season

        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
                selectedSeason = season
            }
        } label: {
            Text(season.name ?? "")
                .appFont(13, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "pill", in: pillNamespace)
                    } else {
                        Capsule()
                            .fill(Color(.secondarySystemBackground))
                    }
                }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.68), value: isSelected)
        .id(season)
    }

    // MARK: - Episode Content

    @ViewBuilder
    private var episodeContent: some View {
        if episodesViewModel.isLoading {
            EpisodeListSkeleton()
                .frame(maxWidth: .infinity, alignment: .top)

        } else if episodesViewModel.apiError {
            ContentUnavailableView {
                Label("Couldn't load episodes", systemImage: "exclamationmark.triangle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange)
            } description: {
                Text("Check your connection and try again.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else if episodesViewModel.episodes?.air_date != nil {
            let episodes = episodesViewModel.episodes?.episodes ?? []
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(episodes.enumerated()), id: \.element) { index, episode in
                        EpisodeView(episode: episode,
                                    seriesName: seriesName,
                                    seriesID: seriesID)

                        // One native row a few episodes in. The episode list
                        // was the only long scroll in the app with no ad at
                        // all, which left Series under-monetised next to
                        // Movies. `NativeAdRow` sizes itself, so an unfilled
                        // request collapses instead of leaving a blank row.
                        if index == 3, episodes.count > 5 {
                            NativeAdRow()
                                .padding(.vertical, 4)
                        }
                    }
                }
            }

        } else {
            ContentUnavailableView {
                Label("Not aired yet", systemImage: "clock")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
            } description: {
                if let airDate = selectedSeason.airDateValue() {
                    Text("Premieres \(airDate.formatted(date: .abbreviated, time: .omitted)).")
                } else {
                    Text("This season hasn't started yet.")
                }
            } actions: {
                if canScheduleReminder {
                    Button(action: toggleSeasonReminder) {
                        Label(seasonReminderOn ? "Reminding" : "Remind Me",
                              systemImage: seasonReminderOn ? "bell.fill" : "bell")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(seasonReminderOn ? .accentColor : .accentColor.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Season reminder

    private var canScheduleReminder: Bool {
        guard let airDate = selectedSeason.airDateValue() else { return false }
        return airDate > Date()
    }

    private var seasonReminderIdentifier: String? {
        guard let number = selectedSeason.season_number else { return nil }
        return ReminderManager.seasonIdentifier(seriesID: seriesID, seasonNumber: number)
    }

    private func syncReminderState() {
        guard let identifier = seasonReminderIdentifier else {
            seasonReminderOn = false
            return
        }
        seasonReminderOn = ReminderManager.isScheduled(identifier: identifier)
    }

    private func toggleSeasonReminder() {
        guard let identifier = seasonReminderIdentifier,
              let airDate = selectedSeason.airDateValue() else {
            return
        }

        if seasonReminderOn {
            ReminderManager.cancel(identifier: identifier)
            seasonReminderOn = false
            showReminderToast = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        let seasonLabel = selectedSeason.name ?? "New season"
        let deepLink = DeepLink(id: seriesID, mediaType: .tv)
        Task {
            let result = await ReminderManager.schedule(
                identifier: identifier,
                title: "Premiering today",
                body: "\(seasonLabel) of \(seriesName) starts today.",
                on: airDate,
                deepLink: deepLink
            )
            switch result {
            case .scheduled:
                seasonReminderOn = true
                showReminderToast = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .authorizationDenied:
                showNotificationSettingsAlert = true
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .failed:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }
}
