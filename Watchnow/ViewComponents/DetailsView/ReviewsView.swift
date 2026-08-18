//
//  ReviewsView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 5/6/22.
//
//  Redesigned review cards:
//    - Circle avatar (Gravatar when available, initials fallback)
//    - Author + date in a two-line identity block
//    - Orange rating badge (★ N/10) pinned to the top-right
//    - 3-line content preview with inline "Read more" expand toggle
//    - Tapping the card opens the full review in a detail sheet
//

import SwiftUI

struct ReviewsView: View {

    let reviews: [Reviews]
    private let inlineLimit = 2

    @State private var isAllPresented = false
    @State private var isReviewPresented = false
    @State private var selectedReview: Reviews?

    private var visibleReviews: [Reviews] {
        Array(reviews.prefix(inlineLimit))
    }

    private var hasMore: Bool { reviews.count > inlineLimit }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(visibleReviews, id: \.self) { review in
                ReviewCard(review: review) {
                    selectedReview = review
                    isReviewPresented = true
                }
            }

            if hasMore {
                Button {
                    isAllPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Text("See all \(reviews.count) reviews")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $isAllPresented) {
            AllReviewsSheet(reviews: reviews)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $isReviewPresented) {
            ReviewSheet(review: $selectedReview)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Review Card

private struct ReviewCard: View {

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
                        Text(review.author_details?.username ?? review.author ?? "Anonymous")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let date = formattedDate(review.created_at) {
                            Text(date)
                                .font(.system(size: 11))
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
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(isExpanded ? nil : 3)
                            .multilineTextAlignment(.leading)
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
                        // Prevent the expand tap from also firing the card tap
                        .simultaneousGesture(TapGesture())
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    @ViewBuilder
    private var authorAvatar: some View {
        if let path = review.author_details?.avatar_path,
           path.contains("https") {
            GenericImageView(url: path,
                             width: 36, height: 36,
                             cornerRadius: 0,
                             showShadow: false)
                .clipShape(Circle())
                .frame(width: 36, height: 36)
        } else {
            // Neutral initials fallback — author identity isn't a thing
            // that needs colour, just clarity.
            Circle()
                .fill(Color(.tertiarySystemFill))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(initials)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func ratingBadge(_ rating: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 9, weight: .bold))
            Text("\(rating)/10")
                .font(.system(size: 12, weight: .bold))
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
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: date)
    }
}

// MARK: - All Reviews Sheet

private struct AllReviewsSheet: View {

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
                .animation(.easeInOut(duration: 0.2), value: sortOrder)
                .animation(.easeInOut(duration: 0.2), value: ratedOnly)
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
                    Label(order.rawValue, systemImage: order.icon).tag(order)
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
                        Text(review?.author_details?.username ?? review?.author ?? "Anonymous")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)

                        if let date = formattedDate(review?.created_at) {
                            Text(date)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if let rating = review?.author_details?.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("\(rating)/10")
                                .font(.system(size: 14, weight: .bold))
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
                    .font(.system(size: 15))
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
        if let path = review?.author_details?.avatar_path,
           path.contains("https") {
            GenericImageView(url: path,
                             width: 44, height: 44,
                             cornerRadius: 0,
                             showShadow: false)
                .clipShape(Circle())
                .frame(width: 44, height: 44)
        } else {
            let name = review?.author_details?.username ?? review?.author ?? "?"
            Circle()
                .fill(Color(.tertiarySystemFill))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func formattedDate(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: iso)
            ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: date)
    }
}
