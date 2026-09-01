//
//  EpisodesView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 16/8/22.
//
//  Redesigned episode row:
//    - 16:9 still thumbnail (128×72) with episode-number pill overlay
//    - Title + compact meta row (air date · star rating)
//    - 2-line overview snippet
//    - Inset divider aligned to the text column so rows breathe
//

import SwiftUI

struct EpisodeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    var episode: Episode
    /// Series name used in the reminder notification body. Optional so the
    /// preview / detached usages still compile; if nil the body falls back
    /// to "this episode".
    var seriesName: String? = nil
    /// TMDB series ID — embedded in the notification's deeplink payload so
    /// tapping the banner opens the parent series' details screen.
    var seriesID: Int? = nil

    @State private var isExpanded = false
    @State private var isReminderOn = false
    @State private var showNotificationSettingsAlert = false

    private let thumbWidth: CGFloat = 128
    private let thumbHeight: CGFloat = 72
    private let thumbCornerRadius: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                thumbnail
                info
                if isFutureEpisode {
                    reminderBell
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Inset divider — starts at the text column, not the screen edge
            Divider()
                .padding(.leading, 16 + thumbWidth + 12)
        }
        .task {
            await ReminderManager.reconcileWithSystem()
            syncReminderState()
        }
        .alert("Notifications are off",
               isPresented: $showNotificationSettingsAlert) {
            Button("Open Settings") { ReminderManager.openNotificationSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable notifications for Watchnow in Settings to set episode reminders.")
        }
    }

    // MARK: - Reminder

    private var isFutureEpisode: Bool {
        guard let airDate = episode.airDateValue() else { return false }
        return airDate > Date()
    }

    private var reminderIdentifier: String? {
        guard let id = episode.id else { return nil }
        return ReminderManager.episodeIdentifier(episodeID: id)
    }

    private var reminderBell: some View {
        Button(action: toggleReminder) {
            Image(systemName: isReminderOn ? "bell.fill" : "bell")
                .appFont(14, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(isReminderOn ? Color.accentColor : .secondary)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(isReminderOn
                              ? Color.accentColor.opacity(0.15)
                              : Color(.secondarySystemBackground))
                }
                // Visible disc stays 32pt so the row's proportions hold; the
                // target around it reaches 44. This sits at the trailing edge
                // of a dense episode row, which is where a short target
                // actually costs you the tap.
                .frame(width: AppTouch.minTarget, height: AppTouch.minTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isReminderOn ? "Cancel reminder" : "Remind me on air date")
    }

    private func syncReminderState() {
        guard let identifier = reminderIdentifier else { return }
        isReminderOn = ReminderManager.isScheduled(identifier: identifier)
    }

    private func toggleReminder() {
        guard let identifier = reminderIdentifier,
              let airDate = episode.airDateValue() else {
            return
        }

        if isReminderOn {
            ReminderManager.cancel(identifier: identifier)
            isReminderOn = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        let episodeLabel = episode.name ?? "Episode \(episode.episode_number ?? 0)"
        let context = seriesName.map { " of \($0)" } ?? ""
        let deepLink = seriesID.map { DeepLink(id: $0, mediaType: .tv) }
        Task {
            let result = await ReminderManager.schedule(
                identifier: identifier,
                title: "Airing today",
                body: "\(episodeLabel)\(context) airs today.",
                on: airDate,
                deepLink: deepLink
            )
            switch result {
            case .scheduled:
                isReminderOn = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .authorizationDenied:
                showNotificationSettingsAlert = true
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .failed:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }

    // MARK: - Thumbnail

    private var thumbnail: some View {
        ZStack(alignment: .bottomLeading) {
            if let path = episode.still_path {
                let url = API.Common.imageUrl(imageId: path)
                GenericImageView(url: url,
                                 width: thumbWidth,
                                 height: thumbHeight,
                                 cornerRadius: thumbCornerRadius,
                                 showShadow: false)
            } else {
                RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: thumbWidth, height: thumbHeight)
                    .overlay {
                        Image(systemName: "film")
                            .appFont(22, weight: .light, relativeTo: .title2)
                            .foregroundStyle(.tertiary)
                    }
            }

            // Episode number pill pinned to the bottom-left of the still
            if let num = episode.episode_number {
                Text("E\(num)")
                    .appFont(10, weight: .bold, relativeTo: .caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background {
                        Capsule()
                            .fill(.black.opacity(0.65))
                    }
                    .padding(6)
            }
        }
        .frame(width: thumbWidth, height: thumbHeight)
        .clipShape(RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous))
    }

    // MARK: - Info

    private var info: some View {
        VStack(alignment: .leading, spacing: 4) {

            // Title
            Text(episode.name ?? "Untitled")
                .appFont(14, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            // Meta: air date · star rating
            HStack(spacing: 8) {
                if let airDate = episode.air_date {
                    Text(airDate)
                        .appFont(11, relativeTo: .caption2)
                        .foregroundStyle(.secondary)
                }

                if let rating = episode.vote_average, rating > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .appFont(9, relativeTo: .caption2)
                            .foregroundStyle(.orange)
                        Text(String(format: "%.1f", rating))
                            .appFont(11, relativeTo: .caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Overview snippet with expand toggle
            if let overview = episode.overview, !overview.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text(overview)
                        .appFont(12, relativeTo: .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                        .animation(reduceMotion ? nil : .easeInOut(duration: AppMotion.quick), value: isExpanded)

                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: AppMotion.quick)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? "Show less" : "Read more")
                            .appFont(12, weight: .semibold, relativeTo: .caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("No overview available.")
                    .appFont(12, relativeTo: .caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - EpisodeListSkeleton

/// Loading state for a season's episodes, shaped like the rows it replaces.
///
/// This slot used to be a centred `ProgressView`. A spinner on an otherwise
/// empty panel says "the app is busy"; a skeleton in the shape of the answer
/// says "the episodes are coming", and keeps the reader's eye where they will
/// appear. The rest of the app had already moved to skeletons — the season
/// tab and the person sheet were the two places still spinning.
struct EpisodeListSkeleton: View {

    /// Enough rows to fill the panel without implying a season length.
    var rows: Int = 4

    var body: some View {
        InlineShimmerContainer {
            VStack(spacing: 18) {
                ForEach(0..<rows, id: \.self) { _ in
                    HStack(alignment: .top, spacing: 12) {
                        ShimmerBox(cornerRadius: AppRadius.small)
                            .frame(width: 128, height: 72)

                        VStack(alignment: .leading, spacing: 7) {
                            ShimmerBox(cornerRadius: AppRadius.micro)
                                .frame(width: 46, height: 11)
                            ShimmerBox(cornerRadius: AppRadius.micro)
                                .frame(maxWidth: .infinity)
                                .frame(height: 14)
                            ShimmerBox(cornerRadius: AppRadius.micro)
                                .frame(width: 110, height: 10)
                            Spacer(minLength: 0)
                        }
                        .frame(height: 72, alignment: .top)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Loading episodes")
    }
}

// MARK: - Preview

struct EpisodeView_Previews: PreviewProvider {
    static var previews: some View {

        let episode = Episode(id: 1,
                              name: "The One Where It All Begins",
                              overview: "A long overview that describes what happens in this episode in some detail, possibly wrapping to two lines.",
                              still_path: nil,
                              vote_average: 8.4,
                              vote_count: 1000,
                              air_date: "2002-02-10",
                              episode_number: 1,
                              season_number: 1)

        EpisodeView(episode: episode)
            .preferredColorScheme(.dark)
    }
}
