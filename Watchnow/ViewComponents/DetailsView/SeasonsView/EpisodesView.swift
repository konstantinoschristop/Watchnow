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
        .onAppear(perform: syncReminderState)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isReminderOn ? Color.accentColor : .secondary)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(isReminderOn
                              ? Color.accentColor.opacity(0.15)
                              : Color(.secondarySystemBackground))
                }
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
            let ok = await ReminderManager.schedule(
                identifier: identifier,
                title: "Airing today",
                body: "\(episodeLabel)\(context) airs today.",
                on: airDate,
                deepLink: deepLink
            )
            isReminderOn = ok
            UINotificationFeedbackGenerator().notificationOccurred(ok ? .success : .warning)
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
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(.tertiary)
                    }
            }

            // Episode number pill pinned to the bottom-left of the still
            if let num = episode.episode_number {
                Text("E\(num)")
                    .font(.system(size: 10, weight: .bold))
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            // Meta: air date · star rating
            HStack(spacing: 8) {
                if let airDate = episode.air_date {
                    Text(airDate)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                if let rating = episode.vote_average, rating > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Overview snippet with expand toggle
            if let overview = episode.overview, !overview.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text(overview)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? "Show less" : "Read more")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("No overview available.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                              episode_number: 1)

        EpisodeView(episode: episode)
            .preferredColorScheme(.dark)
    }
}
