//
//  AdditionalInfoView.swift
//  Watchnow
//
//  The About card at the foot of the details screen.
//
//  Top to bottom:
//    - The tagline, as a pull quote.
//    - For a series with an episode on the way, when it airs — with the
//      same reminder bell the episode list uses. It's the fact people most
//      often scroll down here for, so it comes before the reference rows.
//    - Label / value rows, the App Store "Information" pattern. They
//      replaced a grid of grey stat tiles and stacked uppercase labels,
//      which read like a form: rows scan top to bottom in one line each and
//      fold to label-over-value at accessibility sizes instead of
//      truncating.
//    - Links out: IMDb, the official site, TMDB — each in the in-app
//      browser, like the homepage link always was.
//
//  Everything is optional and the card shrinks to what TMDB actually has;
//  with nothing at all it isn't drawn.
//

import SwiftUI

struct AdditionalInfoView: View {

    let details: ResultDetailsResponse
    /// The title's TMDB page.
    var tmdbURL: URL? = nil

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var openedLink: OpenedLink?

    private struct OpenedLink: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: 14) {
                Text("About")
                    .appFont(22, weight: .bold, relativeTo: .title2)
                    .foregroundStyle(.primary)

                if let tagline = details.getTagline() {
                    Text("\u{201C}\(tagline)\u{201D}", comment: "A film's tagline in quotation marks. Use your language's quotation marks.")
                        .appFont(16, relativeTo: .body, design: .serif)
                        .italic()
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let next = upcomingEpisode {
                    nextEpisodeBanner(next)
                }

                if !rows.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            if index > 0 { Divider() }
                            infoRow(row)
                        }
                    }
                }

                if !links.isEmpty {
                    linkChips
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .detailsCard()
            .padding(.horizontal)
            .sheet(item: $openedLink) { link in
                WebViewSheet(url: link.url)
            }
        }
    }

    private var hasContent: Bool {
        details.getTagline() != nil || upcomingEpisode != nil || !rows.isEmpty || !links.isEmpty
    }

    private var isSeries: Bool {
        details.number_of_seasons != nil
    }

    // MARK: - Next episode

    /// The next episode, while it hasn't aired yet — today included, so the
    /// banner doesn't vanish on the morning it airs.
    private var upcomingEpisode: Episode? {
        guard isSeries,
              let next = details.next_episode_to_air,
              let airDate = next.airDateValue(),
              airDate.addingTimeInterval(86_400) > Date() else { return nil }
        return next
    }

    private func nextEpisodeBanner(_ episode: Episode) -> some View {
        let airDate = episode.airDateValue()
        let code: String? = {
            guard let season = episode.season_number, let number = episode.episode_number else { return nil }
            return String(localized: "S\(season) · E\(number)",
                          comment: "Season and episode code, e.g. S4 · E5. Keep it very short.")
        }()

        return HStack(spacing: 12) {
            Image(systemName: "calendar")
                .appFont(18, weight: .semibold, relativeTo: .body)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Next episode", comment: "About card: when the series' next episode airs")
                    if let airDate {
                        Text(verbatim: "·")
                        // UTC, like the date was parsed: west of Greenwich it
                        // would otherwise show the day before.
                        Text(airDate.formatted(Date.FormatStyle(date: .omitted, time: .omitted, timeZone: .gmt)
                            .weekday(.abbreviated).day().month(.abbreviated)))
                    }
                }
                .appFont(12, weight: .semibold, relativeTo: .caption)
                .foregroundStyle(Color.accentColor)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let code {
                        Text(code)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    if let name = episode.name, !name.isEmpty {
                        Text(name)
                            .foregroundStyle(.primary)
                    }
                }
                .appFont(15, weight: .semibold, relativeTo: .subheadline)
                .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            if let airDate, airDate > Date() {
                EpisodeReminderButton(episode: episode,
                                      seriesName: details.name,
                                      seriesID: details.id)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.08), in: AppRadius.shape(AppRadius.panel))
    }

    // MARK: - Rows

    private struct Row {
        let label: String
        let value: String
        /// Read by VoiceOver instead of `value`, when the shown one is
        /// abbreviated ("$63M").
        var spokenValue: String? = nil
    }

    private var rows: [Row] {
        var rows: [Row] = []

        if isSeries {
            if let date = Self.longDate(details.first_air_date) {
                rows.append(Row(label: String(localized: "First aired", comment: "About card: a series' premiere date"), value: date))
            }
            if let status = details.status, ["Ended", "Canceled"].contains(status),
               let date = Self.longDate(details.last_episode_to_air?.air_date) {
                rows.append(Row(label: String(localized: "Last aired", comment: "About card: when a finished series' last episode aired"), value: date))
            }
            if let status = details.status, !status.isEmpty {
                rows.append(Row(label: String(localized: "Status", comment: "Details stat label: a series' production status"), value: Self.seriesStatus(status)))
            }
            if let creators = details.getCreatedBy(), !creators.isEmpty {
                rows.append(Row(label: String(localized: "Created by", comment: "About card: a series' creators"), value: creators.formatted(.list(type: .and))))
            }
        } else {
            if let date = details.getDate() {
                rows.append(Row(label: String(localized: "Released", comment: "Details stat label: release date"), value: date))
            }
            if let runtime = details.getRuntime() {
                rows.append(Row(label: String(localized: "Runtime", comment: "Details stat label"), value: runtime))
            }
        }

        if let original = originalTitle {
            rows.append(Row(label: String(localized: "Original title", comment: "About card: the title in its original language"), value: original))
        }
        if let languages = details.getLanguages()?.filter({ !$0.isEmpty }), !languages.isEmpty {
            rows.append(Row(label: String(localized: "Languages", comment: "Details label: spoken languages"), value: languages.formatted(.list(type: .and))))
        }

        if !isSeries {
            if let budget = details.budget, budget > 0 {
                rows.append(Row(label: String(localized: "Budget", comment: "Details stat label"),
                                value: Self.compactDollars(budget),
                                spokenValue: details.getBudget()))
            }
            if let revenue = details.revenue, revenue > 0 {
                rows.append(Row(label: String(localized: "Box office", comment: "About card: a film's worldwide takings"),
                                value: Self.compactDollars(revenue),
                                spokenValue: details.getRevenue()))
            }
        }
        return rows
    }

    /// Side by side, the value trailing; stacked once the text is big
    /// enough that a long value would be squeezed into a narrow column.
    private func infoRow(_ row: Row) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 16))

        return layout {
            Text(row.label)
                .foregroundStyle(.secondary)
                .layoutPriority(1)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(row.value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
        }
        .appFont(15, relativeTo: .subheadline)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.label)
        .accessibilityValue(row.spokenValue ?? row.value)
    }

    /// Shown only when it says something the heading doesn't: a translated
    /// title's original, or a foreign title's native script.
    private var originalTitle: String? {
        let shown = (isSeries ? details.name : details.title) ?? ""
        guard let original = isSeries ? details.original_name : details.original_title,
              !original.isEmpty,
              original.compare(shown, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame
        else { return nil }
        return original
    }

    // MARK: - Links

    private struct Link: Identifiable {
        let label: String
        let url: URL
        var id: String { url.absoluteString }
    }

    private var links: [Link] {
        var links: [Link] = []
        if let imdb = details.imdbURL {
            links.append(Link(label: "IMDb", url: imdb))
        }
        if let homepage = details.homepage, !homepage.isEmpty, let url = URL(string: homepage) {
            links.append(Link(label: String(localized: "Website", comment: "About card: link to the title's official website"), url: url))
        }
        if let tmdbURL {
            links.append(Link(label: "TMDB", url: tmdbURL))
        }
        return links
    }

    private var linkChips: some View {
        HStack(spacing: 8) {
            ForEach(links) { link in
                Button {
                    openedLink = OpenedLink(url: link.url)
                } label: {
                    HStack(spacing: 4) {
                        Text(link.label)
                        Image(systemName: "arrow.up.right")
                            .imageScale(.small)
                    }
                    .appFont(14, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Formatting

    /// TMDB's yyyy-MM-dd written out in the app's language, in UTC so it
    /// can't slip a day.
    private static func longDate(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: raw) else { return nil }
        return date.formatted(Date.FormatStyle(date: .long, time: .omitted, timeZone: .gmt))
    }

    /// "$63M" — the size of the number is the point; the full figure is
    /// what VoiceOver reads. TMDB reports money in US dollars.
    private static func compactDollars(_ amount: Double) -> String {
        amount.formatted(.currency(code: "USD")
            .notation(.compactName)
            .precision(.significantDigits(1...3)))
    }

    /// TMDB's series status, which it sends in English whatever the request's
    /// language. Anything unrecognised is shown as TMDB wrote it.
    private static func seriesStatus(_ status: String) -> String {
        switch status {
        case "Returning Series": return String(localized: "Returning Series", comment: "Series status: renewed, more seasons coming")
        case "Ended":            return String(localized: "Ended", comment: "Series status")
        case "Canceled":         return String(localized: "Canceled", comment: "Series status")
        case "In Production":    return String(localized: "In Production", comment: "Series status")
        case "Planned":          return String(localized: "Planned", comment: "Series status")
        case "Pilot":            return String(localized: "Pilot", comment: "Series status: only a pilot episode exists")
        default:                 return status
        }
    }
}
