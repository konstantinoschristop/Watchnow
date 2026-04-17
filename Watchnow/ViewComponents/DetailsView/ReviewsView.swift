//
//  ReviewsView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 5/6/22.
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
        VStack(alignment: .leading, spacing: 10) {
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
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(.horizontal, 10)
        .sheet(isPresented: $isAllPresented) {
            AllReviewsSheet(reviews: reviews)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $isReviewPresented) {
            ReviewSheet(review: $selectedReview)
                .presentationDetents([.medium, .large])
                .background(Color(.secondaryBackground))
        }
    }
}

// MARK: - Review card (inline)

private struct ReviewCard: View {
    let review: Reviews
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    authorAvatar
                    Text(review.author_details?.username ?? "- -")
                        .font(.system(size: 13, weight: .heavy))
                    Spacer()
                    if let rating = review.author_details?.rating {
                        (Text(Image(systemName: "star.fill"))
                            .foregroundColor(.orange)
                         + Text(" ")
                         + Text(String(rating) + "/10"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                }

                Text(review.content ?? "- -")
                    .font(.system(size: 12, weight: .regular))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var authorAvatar: some View {
        if let imageUrl = review.author_details?.avatar_path,
           imageUrl.contains("https") {
            GenericImageView(
                url: imageUrl,
                width: 22, height: 22,
                cornerRadius: 0,
                showShadow: false
            )
            .clipShape(Circle())
            .frame(width: 22, height: 22)
        } else {
            Image(systemName: "person.fill")
                .resizable()
                .clipShape(Circle())
                .frame(width: 22, height: 22)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - All reviews sheet

private struct AllReviewsSheet: View {

    let reviews: [Reviews]
    @State private var selectedReview: Reviews?
    @State private var isReviewPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(reviews, id: \.self) { review in
                        ReviewCard(review: review) {
                            selectedReview = review
                            isReviewPresented = true
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Reviews")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isReviewPresented) {
            ReviewSheet(review: $selectedReview)
                .presentationDetents([.medium, .large])
                .background(Color(.secondaryBackground))
        }
    }
}

// MARK: - Existing detail sheet (kept as-is)

struct ReviewSheet: View {

    @Binding var review: Reviews?

    var body: some View {

        VStack(alignment: .leading, spacing: 5) {
            HStack {
                if let name = review?.author_details?.username {
                    Text("Review by " + name)
                }

                if let rating = review?.author_details?.rating {
                    Spacer()

                    Text(Image(systemName: "star.fill"))
                        .foregroundColor(.orange)
                    + Text(" ") + Text(String(rating) + "/10")
                }
            }
            .padding()
            .font(.system(size: 20, weight: .heavy))

            ScrollView {
                Text(review?.content ?? "- -")
                    .font(.system(size: 15, weight: .medium))
                    .padding()
            }
        }
        .frame(maxWidth: .infinity)
    }
}
