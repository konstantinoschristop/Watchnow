//
//  SeriesRatingsView.swift
//  Watchnow
//
//  The Ratings card on a series: how each season was received, and inside
//  the chosen season, how each episode was.
//
//  Two charts, one selection:
//
//   - Seasons are bars. There are few of them, they are compared against
//     each other rather than read as a sequence, and a bar is the biggest
//     target a chart can offer a thumb. The axis starts at zero — a bar's
//     length *is* its value, so cutting the axis would turn 8.4 vs 8.9 into
//     a cliff — and the exact score sits on top of every bar, which is where
//     the comparison is actually read.
//
//   - Episodes are a line. They *are* a sequence, and the question asked of
//     them is about shape: does it start slow, does the finale land, is
//     there a dud in the middle. A line answers that at a glance where 16
//     thin bars don't. Because a line encodes position rather than length,
//     its axis can fit the season's range honestly, which is what makes a
//     7.8 → 9.1 swing visible at all.
//
//  Choosing a season: tap its bar, or pick it from the menu on the episode
//  chart's heading — the menu is the discoverable way, the bar the quick
//  one. Tapping a point on the line previews that episode below it, and
//  tapping the preview opens the season's full episode list.
//
//  Taps only, deliberately. An earlier version scrubbed on drag, and any
//  drag recogniser on a chart this size inside a vertical ScrollView takes
//  the swipe for itself: the page stopped scrolling wherever a finger
//  landed on the card. A tap never competes with a pan.
//
//  The card opens on the latest rated season and, within it, the highest
//  rated episode, so before anyone touches it it already says something.
//
//  Its footer is the way into every season's full episode list — the sheet
//  with unaired seasons and premiere reminders. With nothing to chart yet
//  (a series whose first season hasn't aired) the footer is all that
//  renders, so that way in never disappears.
//
//  VoiceOver: each chart is one adjustable element — swipe up or down to
//  move between seasons or episodes — because chart scrubbing is not
//  something VoiceOver can perform.
//

import SwiftUI
import Charts

// MARK: - Model

/// Episodes per season, fetched on demand and kept for the screen's life.
@MainActor
final class SeriesRatingsViewModel: ObservableObject {

    /// An aired episode with a score — the only kind the chart draws. An
    /// episode with no votes is left out rather than plotted at zero: a
    /// plunge to nothing would read as "terrible", not "unrated".
    struct RatedEpisode: Identifiable, Equatable {
        let number: Int
        let rating: Double
        let episode: Episode
        var id: Int { number }
    }

    enum EpisodeLoad: Equatable {
        case loading
        /// In episode order. Processed once here, not on every render: the
        /// chart re-evaluates on each step of a scrub, and parsing air dates
        /// each time was enough to make the drag stutter.
        case loaded([RatedEpisode])
        case failed
    }

    @Published private(set) var episodes: [Int: EpisodeLoad] = [:]

    private let seriesID: Int
    private let service: any DetailServiceProtocol

    init(seriesID: Int, service: any DetailServiceProtocol = ServiceInvocation()) {
        self.seriesID = seriesID
        self.service = service
    }

    /// Starts a fetch for `seasonNumber` unless one has already succeeded or
    /// is under way.
    ///
    /// Deliberately not tied to the caller's task: scrubbing across the
    /// season chart cancels the view's task for every season it passes, and
    /// a fetch that dies with it would leave that season stuck on
    /// `.loading`. Let it land and be cached instead — the view debounces,
    /// so only seasons the finger actually rests on get here.
    func ensureEpisodes(seasonNumber: Int) {
        switch episodes[seasonNumber] {
        case .loading, .loaded: return
        case .failed, nil: break
        }
        episodes[seasonNumber] = .loading
        Task {
            do {
                let response = try await service.fetchEpisodes(seriesID: seriesID, seasonNumber: seasonNumber)
                episodes[seasonNumber] = .loaded(Self.rated(response.episodes ?? []))
            } catch {
                episodes[seasonNumber] = .failed
            }
        }
    }

    private static func rated(_ episodes: [Episode]) -> [RatedEpisode] {
        let now = Date()
        return episodes
            .compactMap { episode -> RatedEpisode? in
                guard let number = episode.episode_number,
                      let rating = episode.vote_average, rating > 0,
                      episode.airDateValue().map({ $0 <= now }) ?? false else { return nil }
                return RatedEpisode(number: number, rating: rating, episode: episode)
            }
            .sorted { $0.number < $1.number }
    }
}

private typealias EpisodePoint = SeriesRatingsViewModel.RatedEpisode

// MARK: - View

struct SeriesRatingsView: View {

    /// Seasons that have started airing, in order. A season with no date or
    /// a future one has nothing to rate.
    private let airedSeasons: [Season]
    /// One slot per aired season, rated or not, so a season TMDB hasn't
    /// scored yet — typically the one airing now — can still be picked to
    /// see its episodes.
    private let seasonPoints: [SeasonPoint]
    /// "5 Seasons · 62 Episodes", for the footer.
    let seasonsSummary: String
    /// Opens the full episode list — on the given season, or wherever the
    /// sheet last was when nil.
    let onOpenSeason: (Season?) -> Void

    @StateObject private var model: SeriesRatingsViewModel

    @State private var selectedSeasonNumber: Int?
    @State private var selectedEpisodeNumber: Int?

    /// Bars rise from zero when the card arrives with its data.
    @State private var barsGrown = false
    /// 0 → 1 as the episode line lifts from the floor; replayed per season.
    @State private var lineProgress: Double = 0
    /// Which side the next episode preview slides in from — the side you
    /// moved toward.
    @State private var previewEdge: Edge = .trailing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    /// - Parameter seasons: the series' seasons, Specials already removed
    ///   (`getSeasons()`).
    init(seasons: [Season],
         seriesID: Int,
         seasonsSummary: String,
         onOpenSeason: @escaping (Season?) -> Void) {
        let now = Date()
        let aired = seasons
            .filter { ($0.season_number ?? 0) > 0 && ($0.airDateValue().map { $0 <= now } ?? false) }
            .sorted { ($0.season_number ?? 0) < ($1.season_number ?? 0) }
        self.airedSeasons = aired
        self.seasonPoints = aired.compactMap { season in
            guard let number = season.season_number else { return nil }
            return SeasonPoint(number: number,
                               rating: season.vote_average.flatMap { $0 > 0 ? $0 : nil },
                               name: season.name ?? String(localized: "Season", comment: "A season with no name"))
        }
        self.seasonsSummary = seasonsSummary
        self.onOpenSeason = onOpenSeason
        _model = StateObject(wrappedValue: SeriesRatingsViewModel(seriesID: seriesID))
    }

    var body: some View {
        if let season = activeSeason, !hasNothingToShow {
            VStack(alignment: .leading, spacing: 16) {
                header

                if showsSeasonChart {
                    seasonChart
                    Divider().overlay(Color.primary.opacity(0.04))
                }

                episodeSection(for: season)

                Divider().overlay(Color.primary.opacity(0.04))

                seasonsRow
            }
            .padding(18)
            .detailsCard()
            .padding(.horizontal)
            .task(id: activeSeasonNumber) {
                guard let number = activeSeasonNumber else { return }
                // Debounce, so scrubbing across ten seasons fetches the one
                // the finger stops on rather than all ten.
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                model.ensureEpisodes(seasonNumber: number)
            }
            .onChange(of: activeSeasonNumber) { _, _ in
                selectedEpisodeNumber = nil
            }
            // The card is only built once the series' details have arrived,
            // so appearing *is* the data landing: the bars grow straight
            // away, a beat after the card's own arrival, wherever on the
            // page it is.
            .task {
                guard !barsGrown else { return }
                if reduceMotion || voiceOver {
                    barsGrown = true
                    return
                }
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) { barsGrown = true }
            }
            // Lift the line whenever a season's episodes arrive.
            .task(id: LineKey(season: activeSeasonNumber, loaded: isEpisodeLoadComplete, visible: barsGrown)) {
                guard isEpisodeLoadComplete, barsGrown else {
                    lineProgress = 0
                    return
                }
                if reduceMotion || voiceOver {
                    lineProgress = 1
                    return
                }
                lineProgress = 0
                // One frame at the floor, so the rise has somewhere to
                // start from.
                try? await Task.sleep(for: .milliseconds(30))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.75, dampingFraction: 0.8)) { lineProgress = 1 }
            }
            .sensoryFeedback(.selection, trigger: activeSeasonNumber)
            .sensoryFeedback(.selection, trigger: activeEpisode?.number)
        } else {
            seasonsRow
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .detailsCard(radius: AppRadius.hero)
                .padding(.horizontal)
        }
    }

    // MARK: - Seasons

    private var seasonsRow: some View {
        Button {
            onOpenSeason(activeSeason)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.stack.fill")
                    .appFont(16, weight: .semibold, relativeTo: .body)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.10), in: AppRadius.shape(AppRadius.small))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Seasons")
                        .appFont(15, weight: .semibold, relativeTo: .subheadline)
                        .foregroundStyle(.primary)
                    Text(seasonsSummary)
                        .appFont(12, relativeTo: .caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                HStack(spacing: 3) {
                    Text("See all")
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                }
                .appFont(14, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Color.accentColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Ratings", comment: "Details section title: season and episode ratings for a series")
                .appFont(22, weight: .bold, relativeTo: .title2)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            // Whose ratings these are. TMDB's users, not critics, and not us.
            Text(verbatim: "TMDB")
                .appFont(11, weight: .semibold, relativeTo: .caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Seasons

    private var seasonChart: some View {
        let points = seasonPoints
        let selected = activeSeasonNumber
        let selectedLabel = points.first { $0.number == selected }?.axisLabel
        // Past ten seasons, a score on every bar collides with its
        // neighbours; only the chosen one keeps its label.
        let isDense = points.count > 10

        return Chart(points) { point in
            let isSelected = point.number == selected

            BarMark(x: .value("Season", point.axisLabel),
                    y: .value("Rating", barsGrown ? (point.rating ?? 0) : 0),
                    width: .ratio(isDense ? 0.72 : 0.6))
                .cornerRadius(isDense ? 3 : 7)
                .foregroundStyle(isSelected ? Self.selectedBar : Self.restingBar)
                .annotation(position: .top, spacing: 4) {
                    if !isDense || isSelected {
                        Text(point.rating?.ratingText ?? "–")
                            .font(.system(.footnote, weight: isSelected ? .bold : .semibold))
                            .monospacedDigit()
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .opacity(barsGrown ? 1 : 0)
                    }
                }
        }
        // Headroom above 10, so a perfect score's label sits inside the
        // chart instead of on the card's heading. Still a zero baseline.
        .chartYScale(domain: 0...10.9)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 5, 10]) { _ in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                AxisValueLabel().foregroundStyle(.tertiary)
            }
        }
        .chartXAxis {
            AxisMarks(values: axisLabels(for: points, keeping: selectedLabel)) { value in
                // Thinned by hand above; left to itself the chart truncates
                // a label wider than its bar to a lone "S".
                AxisValueLabel(collisionResolution: .disabled) {
                    if let label = value.as(String.self) {
                        let isSelected = label == selectedLabel
                        Text(label)
                            .font(.system(.caption, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            TapCatcher(proxy: proxy) { x, plotWidth in
                // Bars split the plot into equal bands, so the band under
                // the finger is plain arithmetic — and a tap in the gap
                // between two bars still picks the nearer one.
                guard plotWidth > 0, !points.isEmpty else { return }
                let index = min(points.count - 1, max(0, Int(x / plotWidth * CGFloat(points.count))))
                selectSeason(points[index].number)
            }
        }
        .frame(height: 168)
        // Room for a top score's label, which sits above its bar.
        .padding(.top, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Season ratings", comment: "Accessibility: the chart of ratings per season"))
        .accessibilityValue(seasonAccessibilityValue)
        .accessibilityAdjustableAction { direction in
            step(&selectedSeasonNumber,
                 from: activeSeasonNumber,
                 through: points.map(\.number),
                 direction: direction)
        }
    }

    // MARK: - Episodes

    @ViewBuilder
    private func episodeSection(for season: Season) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                seasonMenu(current: season)
                Text(verbatim: "·")
                    .foregroundStyle(.tertiary)
                Text("Episode ratings", comment: "Ratings card: subtitle above the per-episode chart")
                    .appFont(15, relativeTo: .subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            switch episodeLoad {
            case .loaded:
                if let point = activeEpisode {
                    episodeChart
                    ZStack {
                        episodePreview(point, in: season)
                            .id("\(season.season_number ?? 0)-\(point.number)")
                            .transition(reduceMotion ? .opacity : .push(from: previewEdge))
                    }
                    .clipShape(AppRadius.shape(AppRadius.panel))
                } else {
                    Text("No episode ratings yet", comment: "Ratings card: the season has no rated episodes")
                        .appFont(14, relativeTo: .subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                }

            case .failed:
                HStack(spacing: 10) {
                    Text("Couldn't load episodes")
                        .appFont(14, relativeTo: .subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Retry") {
                        if let number = season.season_number {
                            model.ensureEpisodes(seasonNumber: number)
                        }
                    }
                    .appFont(14, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(Color.accentColor)
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 60)

            case .loading, nil:
                episodeSkeleton
            }
        }
    }

    /// Which season the episode chart shows. A menu rather than relying on
    /// the bars alone: tapping a bar is quick once you know it works, but
    /// nothing about a bar says it can be tapped, and the card opening on
    /// the latest season read as "this only shows the last season".
    @ViewBuilder
    private func seasonMenu(current season: Season) -> some View {
        let title = Text(season.name ?? String(localized: "Season", comment: "A season with no name"))
            .appFont(16, weight: .semibold, relativeTo: .headline)
            .lineLimit(1)

        if seasonPoints.count > 1 {
            Menu {
                Picker(selection: Binding(get: { activeSeasonNumber ?? 0 },
                                          set: { selectSeason($0) })) {
                    ForEach(seasonPoints) { point in
                        Text(point.name).tag(point.number)
                    }
                } label: {
                    EmptyView()
                }
            } label: {
                HStack(spacing: 4) {
                    title
                    Image(systemName: "chevron.up.chevron.down")
                        .appFont(11, weight: .semibold, relativeTo: .caption)
                }
                .foregroundStyle(Color.accentColor)
                .contentShape(Rectangle())
            }
            .menuOrder(.fixed)
        } else {
            title.foregroundStyle(.primary)
        }
    }

    private var episodeChart: some View {
        let points = episodePoints
        let selected = activeEpisode
        let yDomain = ratingDomain(points)
        let first = Double(points.first?.number ?? 1)
        let last = Double(points.last?.number ?? 1)

        return Chart {
            ForEach(points) { point in
                AreaMark(x: .value("Episode", Double(point.number)),
                         yStart: .value("Floor", yDomain.lowerBound),
                         yEnd: .value("Rating", lifted(point.rating, floor: yDomain.lowerBound)))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Self.areaFill)

                LineMark(x: .value("Episode", Double(point.number)),
                         y: .value("Rating", lifted(point.rating, floor: yDomain.lowerBound)))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }

            ForEach(points) { point in
                PointMark(x: .value("Episode", Double(point.number)),
                          y: .value("Rating", lifted(point.rating, floor: yDomain.lowerBound)))
                    .symbolSize(26)
                    .foregroundStyle(Color.accentColor.opacity(0.55))
            }

            if let selected, lineProgress > 0.98 {
                RuleMark(x: .value("Episode", Double(selected.number)))
                    .foregroundStyle(Color.accentColor.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(x: .value("Episode", Double(selected.number)),
                          y: .value("Rating", selected.rating))
                    .symbol {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().strokeBorder(Color(.tertiarySystemBackground), lineWidth: 2))
                            .shadow(color: Color.accentColor.opacity(0.35), radius: 4)
                    }
                    .annotation(position: .top,
                                spacing: 8,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        // On a chip of the card's own colour, so the line
                        // running behind the label can't strike through it.
                        Text(selected.rating.ratingText)
                            .font(.system(.footnote, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(.tertiarySystemBackground), in: Capsule())
                    }
            }
        }
        .chartXScale(domain: (first - 0.5)...(last + 0.5))
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                AxisValueLabel().foregroundStyle(.tertiary)
            }
        }
        .chartXAxis {
            AxisMarks(values: episodeAxisValues(points, keeping: selected?.number)) { value in
                AxisValueLabel(collisionResolution: .disabled) {
                    if let x = value.as(Double.self) {
                        let isSelected = Int(x) == selected?.number
                        Text(Int(x), format: .number)
                            .font(.system(.caption2, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            TapCatcher(proxy: proxy) { x, _ in
                guard let value: Double = proxy.value(atX: x),
                      let nearest = points.min(by: { abs(Double($0.number) - value) < abs(Double($1.number) - value) })
                else { return }
                selectEpisode(nearest.number)
            }
        }
        .frame(height: 128)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Episode ratings", comment: "Ratings card: subtitle above the per-episode chart"))
        .accessibilityValue(episodeAccessibilityValue)
        .accessibilityAdjustableAction { direction in
            step(&selectedEpisodeNumber,
                 from: activeEpisode?.number,
                 through: points.map(\.number),
                 direction: direction)
        }
    }

    private func episodePreview(_ point: EpisodePoint, in season: Season) -> some View {
        let episode = point.episode
        let code = String(localized: "S\(season.season_number ?? 0) · E\(point.number)",
                          comment: "Season and episode code, e.g. S4 · E5. Keep it very short.")
        let isBest = point.number == bestEpisode?.number

        return Button {
            onOpenSeason(season)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                still(for: episode)

                VStack(alignment: .leading, spacing: 3) {
                    ViewThatFits(in: .horizontal) {
                        previewMeta(code: code, rating: point.rating, isBest: isBest)
                        previewMeta(code: code, rating: point.rating, isBest: false)
                    }

                    Text(episode.name ?? String(localized: "Untitled", comment: "An episode with no name"))
                        .appFont(15, weight: .semibold, relativeTo: .subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .appFont(13, relativeTo: .footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

                Image(systemName: "chevron.right")
                    .appFont(13, weight: .semibold, relativeTo: .footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(Color.primary.opacity(0.035), in: AppRadius.shape(AppRadius.panel))
            .contentShape(AppRadius.shape(AppRadius.panel))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Shows all episodes in this season", comment: "Accessibility hint on the episode preview in the Ratings card"))
    }

    private func previewMeta(code: String, rating: Double, isBest: Bool) -> some View {
        HStack(spacing: 6) {
            Text(code)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .foregroundStyle(RatingStyle.tint(for: rating))
                Text(rating.ratingText)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Rated \(rating.ratingText) out of 10", comment: "Accessibility: a 0–10 rating"))
            if isBest {
                Text("Highest rated", comment: "Badge on the season's best-rated episode")
                    .appFont(10, weight: .bold, relativeTo: .caption2)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
        }
        .appFont(12, weight: .semibold, relativeTo: .caption)
        .lineLimit(1)
        .fixedSize()
    }

    @ViewBuilder
    private func still(for episode: Episode) -> some View {
        let width: CGFloat = 96
        let height: CGFloat = 54
        if let path = episode.still_path {
            RemoteImage(url: URL(string: API.Common.imageUrl(imageId: path, width: .backdrop)))
                .frame(width: width, height: height)
                .clipShape(AppRadius.shape(AppRadius.small))
        } else {
            AppRadius.shape(AppRadius.small)
                .fill(Color(.secondarySystemFill))
                .frame(width: width, height: height)
                .overlay {
                    Image(systemName: "film")
                        .appFont(18, weight: .light, relativeTo: .title3)
                        .foregroundStyle(.tertiary)
                }
        }
    }

    private var episodeSkeleton: some View {
        InlineShimmerContainer {
            VStack(alignment: .leading, spacing: 12) {
                ShimmerBox(cornerRadius: AppRadius.small)
                    .frame(height: 128)
                HStack(spacing: 12) {
                    ShimmerBox(cornerRadius: AppRadius.small)
                        .frame(width: 96, height: 54)
                    VStack(alignment: .leading, spacing: 6) {
                        ShimmerBox(cornerRadius: AppRadius.micro).frame(width: 70, height: 10)
                        ShimmerBox(cornerRadius: AppRadius.micro).frame(height: 13)
                        ShimmerBox(cornerRadius: AppRadius.micro).frame(width: 140, height: 10)
                    }
                }
                .padding(10)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(Text("Loading episodes"))
    }
}

// MARK: - Data

private struct SeasonPoint: Identifiable {
    let number: Int
    /// Nil when TMDB has no score for the season yet.
    let rating: Double?
    let name: String
    var id: Int { number }

    var axisLabel: String {
        String(localized: "S\(number)", comment: "Short season label on the ratings chart axis, e.g. S4. Keep it very short.")
    }
}

extension SeriesRatingsView {

    fileprivate static var restingBar: AnyShapeStyle { AnyShapeStyle(Color.accentColor.opacity(0.2)) }
    fileprivate static var selectedBar: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.78)],
                                     startPoint: .top, endPoint: .bottom))
    }
    fileprivate static var areaFill: LinearGradient {
        LinearGradient(colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// One season is not a comparison. Below two, the card is just the
    /// episode chart.
    private var showsSeasonChart: Bool {
        seasonPoints.count >= 2 && seasonPoints.contains { $0.rating != nil }
    }

    private var activeSeasonNumber: Int? {
        if let selectedSeasonNumber { return selectedSeasonNumber }
        let points = seasonPoints
        return points.last(where: { $0.rating != nil })?.number ?? points.last?.number
    }

    private var activeSeason: Season? {
        airedSeasons.first { $0.season_number == activeSeasonNumber }
    }

    private var episodeLoad: SeriesRatingsViewModel.EpisodeLoad? {
        activeSeasonNumber.flatMap { model.episodes[$0] }
    }

    private var episodePoints: [EpisodePoint] {
        guard case .loaded(let points) = episodeLoad else { return [] }
        return points
    }

    /// First of the highest, so a tie goes to the earlier episode.
    private var bestEpisode: EpisodePoint? {
        episodePoints.max { $0.rating < $1.rating }
    }

    private var activeEpisode: EpisodePoint? {
        if let selectedEpisodeNumber,
           let point = episodePoints.first(where: { $0.number == selectedEpisodeNumber }) {
            return point
        }
        return bestEpisode
    }

    /// With no season comparison to make and no rated episodes either, the
    /// card would be a heading over an apology — leave it out.
    private var hasNothingToShow: Bool {
        guard !showsSeasonChart, case .loaded = episodeLoad else { return false }
        return episodePoints.isEmpty
    }

    /// The y-range for the episode line: the season's own spread, padded,
    /// and never narrower than two points, so a season that only wobbles
    /// between 8.1 and 8.3 isn't drawn as a rollercoaster.
    private func ratingDomain(_ points: [EpisodePoint]) -> ClosedRange<Double> {
        let ratings = points.map(\.rating)
        guard let low = ratings.min(), let high = ratings.max() else { return 0...10 }
        let span = max(high - low, 2)
        let middle = (high + low) / 2
        var lower = (middle - span / 2 - 0.3).rounded(.down)
        var upper = (middle + span / 2 + 0.3).rounded(.up)
        if upper > 10 { lower -= upper - 10; upper = 10 }
        if lower < 0 { upper = min(10, upper - lower); lower = 0 }
        return lower...upper
    }

    /// All labels up to a dozen; past that every nth, plus the selected one
    /// so the reader can always see which they're on.
    private func axisLabels(for points: [SeasonPoint], keeping selected: String?) -> [String] {
        let labels = points.map(\.axisLabel)
        return thinned(labels, keeping: labels.firstIndex(where: { $0 == selected }))
            .map { labels[$0] }
    }

    private func episodeAxisValues(_ points: [EpisodePoint], keeping selected: Int?) -> [Double] {
        let numbers = points.map(\.number)
        return thinned(numbers, keeping: numbers.firstIndex(where: { $0 == selected }))
            .map { Double(numbers[$0]) }
    }

    /// Indices of the axis labels to draw. Every one up to a dozen; past
    /// that, every nth — minus any that would sit on top of the selected
    /// label, which always stays.
    private func thinned<T>(_ values: [T], keeping selected: Int?) -> [Int] {
        guard values.count > 12 else { return Array(values.indices) }
        let stride = Int((Double(values.count) / 8).rounded(.up))
        return values.indices.filter { index in
            if index == selected { return true }
            guard index % stride == 0 else { return false }
            guard let selected else { return true }
            return abs(index - selected) > stride / 2
        }
    }

    // MARK: - Selection

    private func selectSeason(_ number: Int) {
        guard number != activeSeasonNumber else { return }
        previewEdge = number > (activeSeasonNumber ?? 0) ? .trailing : .leading
        withAnimation(reduceMotion ? nil : .snappy) { selectedSeasonNumber = number }
    }

    private func selectEpisode(_ number: Int) {
        guard number != activeEpisode?.number else { return }
        previewEdge = number > (activeEpisode?.number ?? 0) ? .trailing : .leading
        withAnimation(reduceMotion ? nil : .snappy) { selectedEpisodeNumber = number }
    }

    /// A rating partway between the chart's floor and its value.
    private func lifted(_ rating: Double, floor: Double) -> Double {
        floor + (rating - floor) * lineProgress
    }

    private struct LineKey: Hashable {
        let season: Int?
        let loaded: Bool
        let visible: Bool
    }

    private var isEpisodeLoadComplete: Bool {
        if case .loaded = episodeLoad { return true }
        return false
    }

    private func step(_ selection: inout Int?,
                      from current: Int?,
                      through values: [Int],
                      direction: AccessibilityAdjustmentDirection) {
        guard let current, let index = values.firstIndex(of: current) else { return }
        switch direction {
        case .increment where index + 1 < values.count:
            selection = values[index + 1]
        case .decrement where index > 0:
            selection = values[index - 1]
        default:
            break
        }
    }

    private var seasonAccessibilityValue: String {
        guard let point = seasonPoints.first(where: { $0.number == activeSeasonNumber }) else { return "" }
        guard let rating = point.rating else { return point.name }
        return point.name + ", " + String(localized: "Rated \(rating.ratingText) out of 10", comment: "Accessibility: a 0–10 rating")
    }

    private var episodeAccessibilityValue: String {
        guard let point = activeEpisode else { return "" }
        let name = point.episode.name ?? String(localized: "Episode \(point.number)", comment: "An episode with no name, by its number")
        return name + ", " + String(localized: "Rated \(point.rating.ratingText) out of 10", comment: "Accessibility: a 0–10 rating")
    }
}

// MARK: - Tap catcher

/// A clear layer over a chart's plot that reports where it was tapped, in
/// plot coordinates. A tap gesture rather than Swift Charts' selection
/// modifiers, which recognise drags — see the file header for why.
private struct TapCatcher: View {

    let proxy: ChartProxy
    /// x within the plot area, and the plot's width.
    let onTap: (CGFloat, CGFloat) -> Void

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    guard let plotFrame = proxy.plotFrame else { return }
                    let plot = geometry[plotFrame]
                    onTap(location.x - plot.minX, plot.width)
                }
        }
    }
}
