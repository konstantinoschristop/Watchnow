//
//  SeasonsDetailsTabView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 15/8/22.
//
//  Bottom sheet with every season's episodes.
//
//  Layout:
//    - Header: series name, the season on screen, its episode count
//    - Season pills — tap to jump; the selection follows a swipe
//    - One page per season, swiped horizontally
//
//  Why pages: switching seasons used to swap one list for a skeleton and
//  then for the next list in the same spot, under a spring animation, with
//  the details screen behind the sheet re-rendering on every tap because
//  the selection was bound straight through to it. Everything on screen
//  moved at once. Now each season is its own page with its own scroll
//  position, the episodes it has loaded stay loaded, and the selection
//  belongs to the sheet — the caller only says where to start.
//

import SwiftUI
import AlertToast

struct SeasonsDetailsTabView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var episodesViewModel: EpisodesViewModel
    let seasons: [Season]
    let seriesID: Int
    let seriesName: String

    /// The season on screen, by number.
    @State private var selectedNumber: Int
    /// Seasons with a premiere reminder set.
    @State private var remindedSeasons: Set<Int> = []
    /// Which way the last reminder toggle went, for the toast's wording.
    @State private var reminderTurnedOn = false
    @State private var showReminderToast = false
    @State private var showNotificationSettingsAlert = false
    @Namespace private var pillNamespace

    init(seasons: [Season],
         initialSeason: Season?,
         seriesID: Int,
         seriesName: String) {

        self.seasons = seasons
        self.seriesID = seriesID
        self.seriesName = seriesName
        let start = initialSeason?.season_number
            ?? seasons.first(where: { $0.air_date != nil })?.season_number
            ?? seasons.first?.season_number
            ?? 1
        _selectedNumber = State(initialValue: start)
        _episodesViewModel = StateObject(wrappedValue: EpisodesViewModel(service: ServiceInvocation(),
                                                                         seriesID: seriesID))
    }

    private var selectedSeason: Season? {
        seasons.first { $0.season_number == selectedNumber }
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            seasonTabs
            Divider()
            pages
        }
        .background(Color(.background))
        .task {
            await ReminderManager.reconcileWithSystem()
            syncReminderState()
        }
        .toast(isPresenting: $showReminderToast, alert: {
            reminderTurnedOn ?
            AlertToast(displayMode: .alert, type: .complete(.green), title: String(localized: "Reminder Set")) :
            AlertToast(displayMode: .alert, type: .error(.red), title: String(localized: "Reminder Removed"))
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
        VStack(alignment: .leading, spacing: 2) {
            Text(seriesName)
                .appFont(13, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(selectedSeason?.name ?? String(localized: "Season", comment: "A season with no name"))
                .appFont(22, weight: .bold, relativeTo: .title2)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("\(episodeCount) Episodes", comment: "Number of episodes")
                .appFont(13, relativeTo: .footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 10)
        // The words change; nothing should move.
        .transaction { $0.animation = nil }
    }

    /// The loaded list's length once there is one, the season's own count
    /// until then — usually the same number, so the header doesn't flicker.
    private var episodeCount: Int {
        if case .loaded(let response)? = episodesViewModel.seasons[selectedNumber],
           let episodes = response.episodes {
            return episodes.count
        }
        return selectedSeason?.episode_count ?? 0
    }

    // MARK: - Season Pills

    private var seasonTabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(seasons, id: \.self) { season in
                        seasonPill(season)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                // Swiping the pages changes the selection without an
                // animation transaction; this gives the indicator one.
                .animation(reduceMotion ? nil : AppMotion.springSnappy, value: selectedNumber)
            }
            .onAppear {
                proxy.scrollTo(selectedNumber, anchor: .center)
            }
            .onChange(of: selectedNumber) { _, number in
                withAnimation(reduceMotion ? nil : AppMotion.springSoft) {
                    proxy.scrollTo(number, anchor: .center)
                }
            }
            .sensoryFeedback(.selection, trigger: selectedNumber)
        }
    }

    private func seasonPill(_ season: Season) -> some View {
        let number = season.season_number ?? 0
        let isSelected = number == selectedNumber

        return Button {
            withAnimation(reduceMotion ? nil : AppMotion.springSnappy) {
                selectedNumber = number
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .id(number)
    }

    // MARK: - Pages

    private var pages: some View {
        TabView(selection: $selectedNumber) {
            ForEach(seasons, id: \.self) { season in
                page(for: season)
                    .tag(season.season_number ?? 0)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    @ViewBuilder
    private func page(for season: Season) -> some View {
        let number = season.season_number ?? 0

        Group {
            switch episodesViewModel.seasons[number] {
            case .loaded(let response)?:
                if response.air_date != nil {
                    episodeList(response.episodes ?? [])
                } else {
                    notAired(season)
                }

            case .failed?:
                ContentUnavailableView {
                    Label("Couldn't load episodes", systemImage: "exclamationmark.triangle")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.orange)
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Retry") { episodesViewModel.ensureEpisodes(seasonNumber: number) }
                        .buttonStyle(.bordered)
                }

            case .loading?, nil:
                VStack(spacing: 0) {
                    EpisodeListSkeleton()
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task { episodesViewModel.ensureEpisodes(seasonNumber: number) }
    }

    private func episodeList(_ episodes: [Episode]) -> some View {
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
    }

    private func notAired(_ season: Season) -> some View {
        let number = season.season_number ?? 0
        let isOn = remindedSeasons.contains(number)

        return ContentUnavailableView {
            Label("Not aired yet", systemImage: "clock")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
        } description: {
            if let airDate = season.airDateValue() {
                Text("Premieres \(airDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt))).",
                     comment: "Season not aired yet; its premiere date")
            } else {
                Text("This season hasn't started yet.")
            }
        } actions: {
            if canScheduleReminder(for: season) {
                Button {
                    toggleReminder(for: season)
                } label: {
                    Label(isOn ? "Reminding" : "Remind Me",
                          systemImage: isOn ? "bell.fill" : "bell")
                }
                .buttonStyle(.borderedProminent)
                .tint(isOn ? .accentColor : .accentColor.opacity(0.9))
            }
        }
    }

    // MARK: - Season reminder

    private func canScheduleReminder(for season: Season) -> Bool {
        guard let airDate = season.airDateValue() else { return false }
        return airDate > Date()
    }

    private func reminderIdentifier(for season: Season) -> String? {
        guard let number = season.season_number else { return nil }
        return ReminderManager.seasonIdentifier(seriesID: seriesID, seasonNumber: number)
    }

    private func syncReminderState() {
        remindedSeasons = Set(seasons.compactMap { season in
            guard let number = season.season_number,
                  let identifier = reminderIdentifier(for: season),
                  ReminderManager.isScheduled(identifier: identifier) else { return nil }
            return number
        })
    }

    private func toggleReminder(for season: Season) {
        guard let number = season.season_number,
              let identifier = reminderIdentifier(for: season),
              let airDate = season.airDateValue() else {
            return
        }

        if remindedSeasons.contains(number) {
            ReminderManager.cancel(identifier: identifier)
            remindedSeasons.remove(number)
            reminderTurnedOn = false
            showReminderToast = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        let seasonLabel = season.name ?? String(localized: "New season", comment: "A season with no name, in a reminder")
        let deepLink = DeepLink(id: seriesID, mediaType: .tv)
        Task {
            let result = await ReminderManager.schedule(
                identifier: identifier,
                title: String(localized: "Premiering today", comment: "Season reminder notification title"),
                body: String(localized: "\(seasonLabel) of \(seriesName) starts today.", comment: "Season reminder notification body: season name, then series name"),
                on: airDate,
                deepLink: deepLink
            )
            switch result {
            case .scheduled:
                remindedSeasons.insert(number)
                reminderTurnedOn = true
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
