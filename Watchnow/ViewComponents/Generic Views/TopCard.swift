//
//  TopCard.swift
//  Watchnow
//
//  Created by k.christopoulos on 5/8/21.
//

import SwiftUI
import Kingfisher

/// Ranked horizontal card for the trending sections on the home screen
/// (e.g. "Hot Right Now", "Binge-Worthy Today").
///
/// Landscape backdrop with a tinted `#N` rank badge on the leading
/// corner and an optional `NEW` / `SOON` status pill on the trailing
/// corner, then a clean title + meta strip (rating • year) below that
/// mirrors `BottomCard`. The rank chip speaks two visual languages in
/// one shape: top-3 rows carry medal colours (gold/silver/bronze) to
/// signal the podium, and everything from #4 on picks up the media
/// type's colour (accent for movies, purple for TV) so the chip
/// reinforces the row's content at a glance.
struct TopCard: View {
    var content: Result
    var screenType: ScreenTypes
    /// 1-based rank within the section. Passed down from
    /// `ScrollableContentView` via the enumerated `ForEach`.
    var rank: Int
    @Namespace private var namespace

    private let backdropHeight: CGFloat = 112
    private let cornerRadius: CGFloat = 12

    var body: some View {
        NavigationLink {
            let model = ContentDetailsModel(screenType: screenType, result: content)
            let vm = ContentDetailsViewModel(model: model)
            ContentDetailsView(detailsViewModel: vm)
                .navigationTransition(.zoom(sourceID: content.id ?? 0, in: namespace))
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                backdrop
                metadata
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .matchedTransitionSource(id: content.id ?? 0, in: namespace)
    }

    // MARK: - Backdrop

    /// Backdrop image drawn via `KFImage` directly (rather than
    /// `BackdropImage`) so we can pin `.fill` + fixed `.frame` + explicit
    /// corner radius without fighting the wrapper's own `.fit` +
    /// `cornerRadius(15)` defaults. Otherwise the image letterboxes inside
    /// the rounded frame and leaves a visible gap on the top/bottom.
    private var backdrop: some View {
        KFImage.url(content.getBackdropURL())
            .downsampling(size: CGSize(width: 500, height: 282))
            .loadImmediately()
            .fromMemoryCacheOrRefresh()
            .cacheOriginalImage()
            .fade(duration: 0.25)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: backdropHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
            .overlay(alignment: .topLeading) { rankBadge.padding(7) }
            .overlay(alignment: .topTrailing) {
                if let status = statusBadge {
                    StatusPill(status: status).padding(7)
                }
            }
    }

    // MARK: - Rank badge
    //
    // Accent/medal-tinted capsule with `#N`. The `#` sits at a lighter
    // weight so the numeral is what the eye lands on, but the hash keeps
    // the badge from reading as "score" or "count" at a glance.

    private var rankBadge: some View {
        HStack(spacing: 1) {
            Text("#")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            Text("\(rank)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(rankTint, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
    }

    /// Gold / silver / bronze for the podium; media-type colour beyond.
    /// The podium colours use hand-picked hex rather than `.yellow` /
    /// `.gray` / `.brown` so they actually read as metals against the
    /// backdrop — system yellow especially tends to wash out.
    private var rankTint: Color {
        switch rank {
        case 1: return Color(red: 1.00, green: 0.80, blue: 0.20) // gold
        case 2: return Color(red: 0.80, green: 0.80, blue: 0.85) // silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20) // bronze
        default:
            // Mirrors `MediaTypeBadge` in the search/watchlist row so the
            // chip colour and the media-type colour line up.
            return content.getMediaType() == "TV Series" ? .purple : .accentColor
        }
    }

    // MARK: - Metadata

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(content.getResultTitle())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            metaRow
        }
    }

    /// Rating chip + release year, separated by a dot. Rendered
    /// conditionally so a missing rating or date collapses cleanly.
    @ViewBuilder
    private var metaRow: some View {
        let year = yearString
        let ratingText = rating.map { String(format: "%.1f", $0) }

        if ratingText != nil || year != nil {
            HStack(spacing: 5) {
                if let ratingText {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(RatingStyle.tint(for: rating))
                        Text(ratingText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                if ratingText != nil, year != nil {
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                if let year {
                    Text(year)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var rating: Double? {
        guard let rating = content.vote_average, rating > 0 else { return nil }
        return rating
    }

    private var yearString: String? {
        let raw = content.getReleaseDate(addSeparator: false)
        return raw.isEmpty ? nil : raw
    }

    // MARK: - Status pill (NEW / SOON)

    /// `NEW` for titles released in the last 14 days, `SOON` for future
    /// release dates, `nil` otherwise. Parsed inline so we don't need to
    /// thread a `Date` through the model layer just for a pill.
    /// Shared formatter — `DateFormatter` init is expensive; allocating one
    /// per render during scroll causes measurable main-thread cost.
    private static let releaseDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar  = Calendar(identifier: .iso8601)
        f.locale    = Locale(identifier: "en_US_POSIX")
        f.timeZone  = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var statusBadge: StatusPill.Status? {
        let raw = (content.release_date?.isEmpty == false
                   ? content.release_date
                   : content.first_air_date) ?? ""
        guard !raw.isEmpty else { return nil }

        guard let date = Self.releaseDateFormatter.date(from: raw) else { return nil }
        let now = Date()

        if date > now { return .soon }

        let days = Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0
        if days <= 14 { return .new }

        return nil
    }
}

// MARK: - StatusPill

/// Tiny "NEW" / "SOON" pill overlaid on the backdrop. Lives opposite the
/// rank chip so the two corner accents balance visually. The tint
/// shadows the semantic: green for freshly-released, blue for upcoming.
struct StatusPill: View {
    enum Status {
        case new, soon

        var title: String {
            switch self {
            case .new: return "NEW"
            case .soon: return "SOON"
            }
        }

        var tint: Color {
            switch self {
            case .new: return .green
            case .soon: return .blue
            }
        }
    }

    let status: Status

    var body: some View {
        Text(status.title)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(status.tint, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
    }
}
