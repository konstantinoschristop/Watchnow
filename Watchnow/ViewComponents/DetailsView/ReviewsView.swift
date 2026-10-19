//
//  ReviewsView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 5/6/22.
//
//  The User Reviews section on the details screen.
//
//    User Reviews                                See all ›
//    8 reviews · ★ 7.6 average
//    [ quote card ][ quote card ][ quo…
//
//  A swipeable row of quote cards, the App Store's grammar for reviews: the
//  review's words are the point, so each card leads with them — a few lines
//  of the text under a large quotation mark — with the stars, the date and
//  who wrote it framing it. The next card peeks in from the edge to say
//  there's more. Tapping a card opens the whole review; "See all" opens the
//  sortable list.
//
//  TMDB hands review text over as the reviewer typed it — Markdown, stray
//  HTML, Windows line endings — so previews are cleaned to plain prose.
//

import SwiftUI

struct ReviewsView: View {

    let reviews: [Reviews]
    private let inlineLimit = 10

    @State private var isAllPresented = false
    @State private var isReviewPresented = false
    @State private var selectedReview: Reviews?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailsSectionHeader(title: String(localized: "User Reviews"), subtitle: summary) {
                SeeAllButton { isAllPresented = true }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(Array(reviews.prefix(inlineLimit)), id: \.self) { review in
                        ReviewQuoteCard(review: review) {
                            selectedReview = review
                            isReviewPresented = true
                        }
                        // A single review takes the full width; otherwise
                        // the next one peeks in from the edge.
                        .containerRelativeFrame(.horizontal) { length, _ in
                            reviews.count == 1 ? length - 32 : length * 0.82
                        }
                        .carouselDepth()
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
        .sheet(isPresented: $isAllPresented) {
            AllReviewsSheet(reviews: reviews)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $isReviewPresented) {
            ReviewSheet(review: $selectedReview)
                .presentationDetents([.medium, .large])
        }
    }

    /// "8 reviews · ★ 7.6 average". The average only appears once two or
    /// more reviewers left a score — one score isn't an average.
    private var summary: String {
        let count = String(localized: "\(reviews.count) reviews", comment: "How many user reviews a title has")
        let scores = reviews.compactMap { $0.author_details?.rating }.filter { $0 > 0 }
        guard scores.count >= 2 else { return count }
        let average = Double(scores.reduce(0, +)) / Double(scores.count)
        return count + " · ★ " + String(localized: "\(average.ratingText) average", comment: "Average score across user reviews, e.g. 7.6 average")
    }
}

// MARK: - Quote card

private struct ReviewQuoteCard: View {

    let review: Reviews
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 196

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    if let rating = review.author_details?.rating, rating > 0 {
                        ReviewStars(rating: rating)
                    }
                    Spacer(minLength: 8)
                    if let date = ReviewText.date(review.created_at) {
                        Text(date)
                            .appFont(12, relativeTo: .caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(ReviewText.plain(review.content ?? ""))
                    .appFont(15, relativeTo: .subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(1.5)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(alignment: .topLeading) {
                        // A large, faint opening quote behind the first
                        // line — the card's one ornament.
                        Text(verbatim: "\u{201C}")
                            .font(.system(size: 64, weight: .bold, design: .serif))
                            .foregroundStyle(Color.accentColor.opacity(0.14))
                            .offset(x: -12, y: -31)
                            .accessibilityHidden(true)
                    }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    ReviewAvatar(review: review, size: 26)
                    Text(ReviewText.author(review))
                        .appFont(13, weight: .semibold, relativeTo: .footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .appFont(12, weight: .semibold, relativeTo: .caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .frame(height: cardHeight, alignment: .top)
            .detailsCard(radius: AppRadius.hero)
            .contentShape(AppRadius.shape(AppRadius.hero))
        }
        .buttonStyle(CarouselPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Shows the full review", comment: "Accessibility hint on a review card"))
    }
}

/// Five stars from TMDB's 0–10 score, halves included.
private struct ReviewStars: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: symbol(for: index))
            }
            Text(verbatim: "\(rating)/10")
                .monospacedDigit()
                .padding(.leading, 4)
                .foregroundStyle(.secondary)
        }
        .appFont(11, weight: .bold, relativeTo: .caption2)
        .foregroundStyle(RatingStyle.tint(for: Double(rating)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rated \(Double(rating).ratingText) out of 10", comment: "Accessibility: a 0–10 rating"))
    }

    private func symbol(for index: Int) -> String {
        let halfStars = rating            // 0–10 is already in half-stars
        let filled = index * 2
        if halfStars >= filled + 2 { return "star.fill" }
        if halfStars == filled + 1 { return "star.leadinghalf.filled" }
        return "star"
    }
}

/// The reviewer's picture — TMDB stores either its own image path or a
/// full Gravatar URL behind a stray leading slash — or their initial.
struct ReviewAvatar: View {
    let review: Reviews
    let size: CGFloat

    var body: some View {
        Group {
            if let url = ReviewText.avatarURL(review.author_details?.avatar_path) {
                RemoteImage(url: url) {
                    initial
                }
            } else {
                initial
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initial: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.14))
            .overlay {
                Text(String(ReviewText.author(review).prefix(1)).uppercased(with: .current))
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
            }
    }
}

/// Cleaning and formatting shared by the review views.
enum ReviewText {

    static func author(_ review: Reviews) -> String {
        review.author_details?.username ?? review.author
            ?? String(localized: "Anonymous", comment: "Review author with no name")
    }

    /// Markdown and HTML reduced to plain prose, paragraphs to single
    /// line breaks — for previews, where a blank line wastes one of four.
    static func plain(_ content: String) -> String {
        var text = content.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            text = String(attributed.characters)
        }
        text = text.replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func avatarURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("/http") { return URL(string: String(path.dropFirst())) }
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: API.Common.imageUrl(imageId: path, width: .poster))
    }

    static func date(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return nil }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Review Card

private struct ReviewCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    let review: Reviews
    let onTap: () -> Void

    @State private var isExpanded = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {

                // Header: avatar + identity + rating badge
                HStack(alignment: .top, spacing: 10) {
                    authorAvatar

                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.author_details?.username ?? review.author ?? String(localized: "Anonymous", comment: "Review author with no name"))
                            .appFont(13, weight: .bold, relativeTo: .footnote)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let date = formattedDate(review.created_at) {
                            Text(date)
                                .appFont(11, relativeTo: .caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if let rating = review.author_details?.rating {
                        ratingBadge(rating)
                    }
                }

                // Content preview
                if let content = review.content, !content.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(content)
                            .appFont(13, relativeTo: .footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(isExpanded ? nil : 3)
                            .multilineTextAlignment(.leading)
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
                        // Prevent the expand tap from also firing the card tap
                        .simultaneousGesture(TapGesture())
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private var authorAvatar: some View {
        ReviewAvatar(review: review, size: 36)
    }

    private func ratingBadge(_ rating: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .appFont(9, weight: .bold, relativeTo: .caption2)
            Text("\(rating)/10")
                .appFont(12, weight: .bold, relativeTo: .caption)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(Color.orange.opacity(0.15))
        }
    }

    private var initials: String {
        let name = review.author_details?.username ?? review.author ?? "?"
        return String(name.prefix(1)).uppercased()
    }

    private func formattedDate(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: iso)
            ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return nil }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - All Reviews Sheet

private struct AllReviewsSheet: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    let reviews: [Reviews]
    @State private var selectedReview: Reviews?
    @State private var isReviewPresented = false
    @State private var sortOrder: SortOrder = .mostRecent
    @State private var ratedOnly = false

    /// All-client-side ordering — TMDB returns reviews in submission order
    /// (newest first), and the full list is small enough that re-sorting on
    /// every menu toggle is free.
    enum SortOrder: String, CaseIterable, Identifiable {
        case mostRecent   = "Most Recent"
        case oldestFirst  = "Oldest First"
        case highestRated = "Highest Rated"
        case lowestRated  = "Lowest Rated"
        case mostDetailed = "Most Detailed"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .mostRecent:   return String(localized: "Most Recent", comment: "Review sort order")
            case .oldestFirst:  return String(localized: "Oldest First", comment: "Review sort order")
            case .highestRated: return String(localized: "Highest Rated", comment: "Review sort order")
            case .lowestRated:  return String(localized: "Lowest Rated", comment: "Review sort order")
            case .mostDetailed: return String(localized: "Most Detailed", comment: "Review sort order: longest reviews first")
            }
        }

        var icon: String {
            switch self {
            case .mostRecent:   return "clock"
            case .oldestFirst:  return "clock.arrow.circlepath"
            case .highestRated: return "star.fill"
            case .lowestRated:  return "star.slash"
            case .mostDetailed: return "text.justify"
            }
        }
    }

    /// The reviews list after applying both the rated-only filter and
    /// the active sort order.
    ///
    /// Reviews without a rating are pushed to the end when sorting by
    /// rating — by giving them an out-of-range sentinel (`0` for highest,
    /// `Int.max` for lowest) instead of dropping them. The dedicated
    /// `ratedOnly` toggle is the explicit way to remove them entirely.
    private var displayedReviews: [Reviews] {
        let filtered = ratedOnly
            ? reviews.filter { ($0.author_details?.rating ?? 0) > 0 }
            : reviews

        return filtered.sorted { lhs, rhs in
            switch sortOrder {
            case .mostRecent:
                return (lhs.created_at ?? "") > (rhs.created_at ?? "")
            case .oldestFirst:
                return (lhs.created_at ?? "") < (rhs.created_at ?? "")
            case .highestRated:
                return (lhs.author_details?.rating ?? 0) > (rhs.author_details?.rating ?? 0)
            case .lowestRated:
                return (lhs.author_details?.rating ?? Int.max) < (rhs.author_details?.rating ?? Int.max)
            case .mostDetailed:
                return (lhs.content?.count ?? 0) > (rhs.content?.count ?? 0)
            }
        }
    }

    /// True when the user has touched the menu — drives the toolbar
    /// glyph's filled variant so they have a quick visual cue that the
    /// list is no longer the default ordering.
    private var hasCustomFilters: Bool {
        sortOrder != .mostRecent || ratedOnly
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if displayedReviews.isEmpty {
                        ContentUnavailableView(
                            "No rated reviews",
                            systemImage: "star.slash",
                            description: Text("Turn off \"Rated reviews only\" to see all reviews.")
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(displayedReviews, id: \.self) { review in
                            ReviewCard(review: review) {
                                selectedReview = review
                                isReviewPresented = true
                            }
                        }
                    }
                }
                .padding(16)
                .animation(reduceMotion ? nil : .easeInOut(duration: AppMotion.quick), value: sortOrder)
                .animation(reduceMotion ? nil : .easeInOut(duration: AppMotion.quick), value: ratedOnly)
            }
            .background(Color(.background))
            .navigationTitle("Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
            }
        }
        .modifier(SoftScrollEdgeEffectStyleModifier())
        .sheet(isPresented: $isReviewPresented) {
            ReviewSheet(review: $selectedReview)
                .presentationDetents([.medium, .large])
        }
    }

    /// Sort + filter dropdown. The `Picker` inside `Menu` renders as a
    /// native iOS radio group with a checkmark on the active option, so
    /// the user can see at a glance which sort is currently applied.
    /// "Rated only" lives below a divider as a separate toggle since
    /// it's an *additional* filter, not another sort order.
    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sortOrder) {
                ForEach(SortOrder.allCases) { order in
                    Label(order.title, systemImage: order.icon).tag(order)
                }
            }

            Divider()

            Toggle(isOn: $ratedOnly) {
                Label("Rated reviews only", systemImage: "star.leadinghalf.filled")
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .symbolVariant(hasCustomFilters ? .fill : .none)
        }
        .tint(.accentColor)
        .sensoryFeedback(.selection, trigger: sortOrder)
        .sensoryFeedback(.selection, trigger: ratedOnly)
    }
}

// MARK: - Full Review Sheet

struct ReviewSheet: View {

    @Binding var review: Reviews?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    avatarView
                    VStack(alignment: .leading, spacing: 3) {
                        Text(review?.author_details?.username ?? review?.author ?? String(localized: "Anonymous", comment: "Review author with no name"))
                            .appFont(16, weight: .bold, relativeTo: .body)
                            .foregroundStyle(.primary)

                        if let date = formattedDate(review?.created_at) {
                            Text(date)
                                .appFont(12, relativeTo: .caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if let rating = review?.author_details?.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .appFont(11, weight: .bold, relativeTo: .caption2)
                            Text("\(rating)/10")
                                .appFont(14, weight: .bold, relativeTo: .subheadline)
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            Capsule()
                                .fill(Color.orange.opacity(0.15))
                        }
                    }
                }
            }
            .padding(20)

            Divider()

            // Full content
            ScrollView {
                Text(review?.content ?? "")
                    .appFont(15, relativeTo: .subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
        }
        .background(Color(.background))
    }

    @ViewBuilder
    private var avatarView: some View {
        if let review {
            ReviewAvatar(review: review, size: 44)
        }
    }

    private func formattedDate(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: iso)
            ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return nil }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
