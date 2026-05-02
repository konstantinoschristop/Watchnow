//
//  CastView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/2/22.
//

import SwiftUI
import Kingfisher

/// Cast carousel for the details screen.
///
/// Uses portrait-format cards (rounded rectangle photos, not circles) so the
/// framing of the face stays recognizable, with both actor name and character
/// role beneath. A trailing "See all" card opens a full grid when the cast is
/// longer than `inlineLimit`.
struct CastView: View {

    let cast: [Cast]
    /// TMDB id of the title this cast belongs to. Threaded through to the
    /// actor sheet so that "Known For" entries matching this title (the
    /// one the user is currently viewing) collapse to a plain dismiss
    /// instead of pushing a redundant details screen.
    let currentTitleID: Int?
    private let inlineLimit = 10

    @State private var showAll = false

    init(cast: [Cast]?, currentTitleID: Int? = nil) {
        self.cast = cast ?? []
        self.currentTitleID = currentTitleID
    }

    private var visibleCast: [Cast] {
        Array(cast.prefix(inlineLimit))
    }

    private var hasMore: Bool { cast.count > inlineLimit }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(visibleCast, id: \.self) { member in
                    CastCard(member: member, currentTitleID: currentTitleID)
                }

                if hasMore {
                    SeeAllCard(remaining: cast.count - inlineLimit) {
                        showAll = true
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showAll) {
            CastSheet(cast: cast, currentTitleID: currentTitleID)
                .presentationDetents([.large])
        }
    }
}

// MARK: - Card

private struct CastCard: View {

    let member: Cast
    let currentTitleID: Int?

    private let cardWidth: CGFloat = 110
    private let imageHeight: CGFloat = 140

    @State private var isSheetPresented = false

    var body: some View {
        Button {
            guard let path = member.profile_path, !path.isEmpty else { return }
            isSheetPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                portrait
                    .frame(width: cardWidth, height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                Text(member.getName())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let character = member.character, !character.isEmpty {
                    Text(character)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: cardWidth, alignment: .leading)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isSheetPresented) {
            PersonSheetView(
                personID:       member.id ?? 0,
                name:           member.getName(),
                profilePath:    member.profile_path,
                knownFor:       member.known_for,
                currentTitleID: currentTitleID
            )
            // 70% gives the Known For row enough room to read at a
            // glance without forcing a scroll. Drag-up to .large still
            // available when the user wants the full bio.
            .presentationDetents([.fraction(0.7), .large])
        }
    }

    @ViewBuilder
    private var portrait: some View {
        if let path = member.profile_path {
            KFImage.url(URL(string: API.Common.imageUrl(imageId: path)))
                .placeholder { placeholder }
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            initialsPlaceholder
        }
    }

    private var placeholder: some View {
        Rectangle().fill(.ultraThinMaterial)
    }

    private var initialsPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initials(from: member.getName()))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    private func initials(from name: String) -> String {
        let components = name.split(separator: " ").prefix(2)
        return components.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

// MARK: - See all card

private struct SeeAllCard: View {

    let remaining: Int
    let onTap: () -> Void

    private let cardWidth: CGFloat = 110
    private let imageHeight: CGFloat = 140

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                    VStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary.opacity(0.8))
                        Text("+\(remaining)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                .frame(width: cardWidth, height: imageHeight)

                Text("See all")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.blue)
                Text("Full cast")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(width: cardWidth, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Full cast sheet

private struct CastSheet: View {

    let cast: [Cast]
    let currentTitleID: Int?

    // Fixed card width so each cell matches the inline carousel exactly; the
    // adaptive grid flows as many per row as fit.
    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 110), spacing: 16, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(cast, id: \.self) { member in
                        CastCard(member: member, currentTitleID: currentTitleID)
                    }
                }
                .padding()
            }
            .navigationTitle("Cast")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
