//
//  CastView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 13/2/22.
//
//  The Cast section: who made it, then who's in it.
//
//    Cast                                         See all ›
//    [DIRECTOR]  [portrait]  [portrait]  [portrait]  …
//     Name        Name        Name        Name
//                 Character   Character   Character
//
//  - Behind-the-camera first: the director of a film, the creator of a
//    series, set apart by a badge on the photo. It's the credit people
//    recognise a film by as often as its star.
//  - Portraits are cinematic cards with the name set on the photo, over a
//    shade that only darkens its bottom edge; the character sits below.
//  - The photo drifts a little inside its frame as the row scrolls, and
//    the cards at the edges sit back slightly, so the row has depth
//    without anything moving once it's at rest. Cards snap into place.
//
//  Tapping a person opens their sheet; "See all" opens the full cast grid.
//

import SwiftUI

/// A behind-the-camera credit shown at the head of the cast row.
struct CrewCredit: Identifiable, Hashable {
    let id: Int
    let name: String
    /// "Director", "Creator" — already localised.
    let role: String
    /// The badge's glyph.
    let symbol: String
    let profilePath: String?
}

struct CastView: View {

    let cast: [Cast]
    var crew: [CrewCredit] = []
    /// TMDB id of the title this cast belongs to. Threaded through to the
    /// actor sheet so that "Known For" entries matching this title (the
    /// one the user is currently viewing) collapse to a plain dismiss
    /// instead of pushing a redundant details screen.
    let currentTitleID: Int?
    private let inlineLimit = 12

    @State private var showAll = false

    init(cast: [Cast]?, crew: [CrewCredit] = [], currentTitleID: Int? = nil) {
        self.cast = cast ?? []
        self.crew = crew
        self.currentTitleID = currentTitleID
    }

    private var visibleCast: [Cast] {
        Array(cast.prefix(inlineLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailsSectionHeader(title: String(localized: "Cast")) {
                if cast.count > inlineLimit || !crew.isEmpty {
                    SeeAllButton { showAll = true }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(crew) { credit in
                        PersonCard(personID: credit.id,
                                   name: credit.name,
                                   profilePath: credit.profilePath,
                                   caption: nil,
                                   badge: credit.role,
                                   badgeSymbol: credit.symbol,
                                   knownFor: nil,
                                   currentTitleID: currentTitleID)
                            .carouselDepth()
                    }
                    ForEach(visibleCast, id: \.self) { member in
                        PersonCard(member: member, currentTitleID: currentTitleID)
                            .carouselDepth()
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .scrollTargetBehavior(.viewAligned)
            // Room for the card shadows, which a scroll view would clip.
            .scrollClipDisabled()
        }
        .sheet(isPresented: $showAll) {
            CastSheet(cast: cast, crew: crew, currentTitleID: currentTitleID)
                .presentationDetents([.large])
        }
    }
}

// MARK: - Card

/// One person: portrait with their name on it, and what they played (or
/// did) underneath.
private struct PersonCard: View {

    let personID: Int
    let name: String
    let profilePath: String?
    /// The character, under the card.
    let caption: String?
    /// A role badge on the photo — "Director", "Creator".
    let badge: String?
    var badgeSymbol: String = "video.fill"
    let knownFor: [Result]?
    let currentTitleID: Int?

    static let width: CGFloat = 116
    static let height: CGFloat = 156

    @State private var isSheetPresented = false
    /// Two caption lines' worth, reserved on every card — with or without a
    /// caption — so all cards are one height. A lazy row takes its height
    /// from the first card, and when that was the captionless director the
    /// characters under the others spilled into the next section.
    @ScaledMetric(relativeTo: .caption) private var captionReserve: CGFloat = 34

    init(personID: Int, name: String, profilePath: String?, caption: String?,
         badge: String?, badgeSymbol: String = "video.fill", knownFor: [Result]?, currentTitleID: Int?) {
        self.personID = personID
        self.name = name
        self.profilePath = profilePath
        self.caption = caption
        self.badge = badge
        self.badgeSymbol = badgeSymbol
        self.knownFor = knownFor
        self.currentTitleID = currentTitleID
    }

    init(member: Cast, currentTitleID: Int?) {
        self.init(personID: member.id ?? 0,
                  name: member.getName(),
                  profilePath: member.profile_path,
                  caption: member.character.flatMap { $0.isEmpty ? nil : $0 },
                  badge: nil,
                  knownFor: member.known_for,
                  currentTitleID: currentTitleID)
    }

    var body: some View {
        Button {
            guard let profilePath, !profilePath.isEmpty else { return }
            isSheetPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomLeading) {
                    portrait
                    // Darkens only the bottom third, where the name sits.
                    LinearGradient(stops: [.init(color: .clear, location: 0.45),
                                           .init(color: .black.opacity(0.7), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                    Text(name)
                        .appFont(13, weight: .bold, relativeTo: .footnote)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .padding(8)
                }
                .overlay(alignment: .topLeading) {
                    if let badge {
                        Label(badge, systemImage: badgeSymbol)
                            .labelStyle(.titleAndIcon)
                            .appFont(10, weight: .bold, relativeTo: .caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.9), in: Capsule())
                            .padding(7)
                    }
                }
                .frame(width: Self.width, height: Self.height)
                .clipShape(AppRadius.shape(AppRadius.panel))
                .overlay {
                    AppRadius.shape(AppRadius.panel)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                }
                .background {
                    // Behind the clipped photo, not on it: a shadow on the
                    // clipped stack would cost an offscreen pass per card.
                    AppRadius.shape(AppRadius.panel)
                        .fill(Color(.tertiarySystemFill))
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                }

                if let caption {
                    Text(caption)
                        .appFont(12, relativeTo: .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: Self.width, height: Self.height + 6 + captionReserve, alignment: .topLeading)
        }
        .buttonStyle(CarouselPressStyle())
        .accessibilityElement(children: .combine)
        .sheet(isPresented: $isSheetPresented) {
            PersonSheetView(
                personID:       personID,
                name:           name,
                profilePath:    profilePath,
                knownFor:       knownFor,
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
        if let profilePath, !profilePath.isEmpty {
            RemoteImage(url: URL(string: API.Common.imageUrl(imageId: profilePath, width: .poster)),
                        focus: UnitPoint(x: 0.5, y: 0.2))
                // Slightly oversized so the parallax drift never shows an
                // edge.
                .scaleEffect(1.14)
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content.offset(x: phase.value * -10)
                }
        } else {
            initialsPlaceholder
        }
    }

    private var initialsPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initials(from: name))
                .appFont(30, weight: .semibold, relativeTo: .title, design: .rounded)
                .foregroundStyle(.white.opacity(0.9))
                .offset(y: -14)
        }
    }

    private func initials(from name: String) -> String {
        let components = name.split(separator: " ").prefix(2)
        return components.compactMap { $0.first.map(String.init) }.joined().uppercased(with: .current)
    }
}

// MARK: - Carousel depth

extension View {
    /// Cards at the edges of a carousel sit back a little; the ones in
    /// view are untouched.
    func carouselDepth() -> some View {
        scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                .opacity(phase.isIdentity ? 1 : 0.7)
        }
    }
}

// MARK: - Full cast sheet

private struct CastSheet: View {

    let cast: [Cast]
    let crew: [CrewCredit]
    let currentTitleID: Int?

    // Fixed card width so each cell matches the inline carousel exactly; the
    // adaptive grid flows as many per row as fit.
    private let columns = [
        GridItem(.adaptive(minimum: PersonCard.width, maximum: PersonCard.width), spacing: 14, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(crew) { credit in
                        PersonCard(personID: credit.id, name: credit.name, profilePath: credit.profilePath,
                                   caption: nil, badge: credit.role, badgeSymbol: credit.symbol, knownFor: nil,
                                   currentTitleID: currentTitleID)
                    }
                    ForEach(cast, id: \.self) { member in
                        PersonCard(member: member, currentTitleID: currentTitleID)
                    }
                }
                .padding()
            }
            .navigationTitle("Cast")
            .navigationBarTitleDisplayMode(.inline)
        }
        .modifier(SoftScrollEdgeEffectStyleModifier())
    }
}
