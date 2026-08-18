//
//  PersonSheetView.swift
//  Watchnow
//
//  A lightweight sheet that surfaces an actor's biography, key meta
//  (birthday + age, place of birth), and a "Known For" poster reel.
//  Presented with .medium / .large detents so it feels like a peek
//  rather than a full navigation push.
//

import SwiftUI
import Kingfisher

// MARK: - ViewModel

@MainActor
final class PersonViewModel: ObservableObject {

    @Published var person: PersonResponse?
    @Published var isLoading = true
    @Published var hasError = false

    /// Resolved "Known For" titles fetched from `/person/{id}/combined_credits`.
    /// Only populated when the caller didn't already supply a `knownFor`
    /// array via the sheet's init — saves a round-trip when the parent
    /// already had the data (multi-search results carry it inline).
    @Published var combinedCredits: [Result]?
    @Published var isLoadingCredits = false

    private let service = ServiceInvocation()

    func fetch(id: Int) async {
        guard id > 0 else { isLoading = false; return }
        isLoading = true
        hasError  = false
        do {
            person = try await service.fetchPerson(personID: id)
        } catch {
            hasError = true
        }
        isLoading = false
    }

    /// Loads the person's combined credits and exposes the top-N best-
    /// known acting credits as the "Known For" reel. Crew credits are
    /// dropped — the section is meant to show titles the user might
    /// recognise the actor *from*, which is almost always cast work.
    ///
    /// "Best-known" here is `vote_count`: the number of TMDB users who
    /// have actually rated the title. That correlates with real-world
    /// reach far better than the volatile `popularity` field (a "what's
    /// buzzy this week" score) — which previously buried iconic roles
    /// under whatever the actor happened to be in last month. We also
    /// filter unreleased / barely-rated / posterless entries that TMDB
    /// returns as data noise.
    ///
    /// Duplicates (same title, multiple roles) are folded by TMDB id so
    /// the row never repeats a poster.
    func loadCombinedCredits(id: Int, limit: Int = 8) async {
        guard id > 0 else { return }
        isLoadingCredits = true
        defer { isLoadingCredits = false }

        do {
            let response = try await service.fetchCombinedCredits(personID: id)
            let cast = response.cast ?? []

            // Threshold tuned for the long tail — fewer than ~25 votes
            // typically means the title is either unreleased or a fringe
            // credit the actor isn't really associated with.
            let minVotes = 25

            var seen = Set<Int>()
            let candidates = cast.filter { result in
                guard let id = result.id else { return false }
                guard let votes = result.vote_count, votes >= minVotes else { return false }
                guard let poster = result.poster_path, !poster.isEmpty else { return false }
                return seen.insert(id).inserted
            }

            // Sort by vote_count desc; tiebreak on popularity so two
            // similarly-watched titles still surface the currently-relevant
            // one first.
            let sorted = candidates.sorted { lhs, rhs in
                let lv = lhs.vote_count ?? 0
                let rv = rhs.vote_count ?? 0
                if lv != rv { return lv > rv }
                return (lhs.popularity ?? 0) > (rhs.popularity ?? 0)
            }
            combinedCredits = Array(sorted.prefix(limit))
        } catch {
            // Soft-fail: the section just stays empty. The biography +
            // meta blocks on the sheet are still useful, so a Known For
            // failure shouldn't surface a screen-level error state.
            combinedCredits = []
        }
    }
}

// MARK: - Sheet

struct PersonSheetView: View {

    let personID:    Int
    let name:        String
    let profilePath: String?
    /// Pre-loaded from Cast.known_for / Result.known_for — shown with no
    /// extra network call. Optional: sections that can't supply it omit it.
    let knownFor: [Result]?
    /// The TMDB id of the title the sheet was opened *from* (the details
    /// screen the user was viewing when they tapped a cast row). When a
    /// Known For card matches this id, tapping it just dismisses the
    /// sheet — the user is already viewing that title. Pass nil when the
    /// sheet is opened outside a details context (search results,
    /// watchlist, etc.) so every Known For card is fully tappable.
    var currentTitleID: Int? = nil

    @StateObject private var vm = PersonViewModel()
    @State private var isBioExpanded = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // The sheet manages its own NavigationStack. Tapping a Known For
        // card pushes the corresponding ContentDetailsView *inside* the
        // sheet — the user can dismiss to get back to where they were,
        // or drag to .large for full-screen reading mid-navigation.
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .center, spacing: 28) {

                    headerSection

                    if vm.isLoading {
                        ProgressView()
                            .padding(.top, 8)
                    } else if vm.hasError {
                        ContentUnavailableView(
                            "Couldn't load",
                            systemImage: "person.slash",
                            description: Text("Check your connection and try again.")
                        )
                        .padding(.top, 8)
                    } else {
                        if let person = vm.person {
                            if !buildMetaItems(person).isEmpty {
                                metaSection(person)
                            }
                            if let bio = person.biography, !bio.isEmpty {
                                bioSection(bio)
                            }
                        }

                        knownForBlock
                    }
                }
                .padding(.bottom, 36)
                // Force the inner stack to occupy the full sheet height even
                // while content is sparse (e.g. during the initial fetch).
                // Without this, the ScrollView shrinks to fit its content and
                // leaves the bottom half of the sheet showing system chrome
                // through the gap.
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
            }
            // Wire up the value-based navigation destination. NavigationLinks
            // anywhere in the sheet that pass a `Result` push to a fresh
            // ContentDetailsView for that title.
            .navigationDestination(for: Result.self) { result in
                let screenType: ScreenTypes = result.media_type == "movie" ? .movie : .tv
                let model = ContentDetailsModel(screenType: screenType, result: result)
                let vm = ContentDetailsViewModel(model: model)
                ContentDetailsView(detailsViewModel: vm)
            }
        }
        .modifier(SoftScrollEdgeEffectStyleModifier())
        // `presentationBackground` colours the entire sheet container —
        // it survives the ScrollView's intrinsic-size shrinkage during
        // loading. The `.background` modifier on the ScrollView itself
        // only paints behind content, which is why "half the sheet"
        // appeared transparent when only a header + spinner were drawn.
        .presentationBackground(Color(.background))
        .task { await vm.fetch(id: personID) }
        // Only fetch credits if the caller didn't supply them. Avoids a
        // wasteful round-trip when opening the sheet from a multi-search
        // result (which already carries `known_for`).
        .task {
            guard knownFor == nil else { return }
            await vm.loadCombinedCredits(id: personID)
        }
    }

    /// Resolves which list to show in the "Known For" section, with a
    /// shimmer skeleton while the credits endpoint is in flight. Order of
    /// precedence: caller-supplied `knownFor` (instant) → fetched
    /// `combinedCredits` (after the round-trip) → nothing (section hides).
    @ViewBuilder
    private var knownForBlock: some View {
        if let works = knownFor, !works.isEmpty {
            knownForSection(works)
        } else if let fetched = vm.combinedCredits, !fetched.isEmpty {
            knownForSection(fetched)
        } else if vm.isLoadingCredits {
            knownForSkeleton
        }
    }

    private var knownForSkeleton: some View {
        InlineShimmerContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Known For")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(0..<5, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 6) {
                                ShimmerBox(cornerRadius: 10)
                                    .frame(width: 90, height: 135)
                                ShimmerBox(cornerRadius: 4)
                                    .frame(width: 70, height: 10)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)
                }
                .disabled(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            profilePhoto
                .padding(.top, 28)

            Text(name)
                .font(.custom("AvenirNext-Bold", size: 24))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("ACTOR")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.orange.opacity(0.3), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    private var profilePhoto: some View {
        let size: CGFloat = 110
        // Prefer the freshly fetched PersonResponse path; fall back to the
        // value passed at init (already loaded in the cast carousel) so the
        // photo appears instantly without waiting for the API round-trip.
        let resolvedPath = vm.person?.profile_path ?? profilePath

        if let path = resolvedPath, !path.isEmpty {
            KFImage.url(URL(string: API.Common.imageUrl(imageId: path)))
                .loadImmediately()
                .fromMemoryCacheOrRefresh()
                .cacheOriginalImage()
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        } else {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.orange.opacity(0.45), Color.orange.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: size, height: size)
                .overlay {
                    Text(initials)
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
        }
    }

    // MARK: - Meta

    @ViewBuilder
    private func metaSection(_ person: PersonResponse) -> some View {
        VStack(spacing: 12) {
            ForEach(buildMetaItems(person), id: \.label) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                        .frame(width: 22)
                    Text(item.label)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private struct MetaItem {
        let icon: String
        let label: String
    }

    private func buildMetaItems(_ person: PersonResponse) -> [MetaItem] {
        var items: [MetaItem] = []

        if let birthday = person.birthday, !birthday.isEmpty {
            var label = formattedDate(birthday) ?? birthday
            if person.deathday == nil, let age = age(from: birthday) {
                label += "  ·  age \(age)"
            }
            items.append(.init(icon: "birthday.cake", label: label))
        }
        if let deathday = person.deathday, !deathday.isEmpty {
            let label = formattedDate(deathday) ?? deathday
            items.append(.init(icon: "moon.stars", label: label))
        }
        if let place = person.place_of_birth, !place.isEmpty {
            items.append(.init(icon: "mappin.and.ellipse", label: place))
        }

        return items
    }

    // MARK: - Biography

    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Biography")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text(bio)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .lineLimit(isBioExpanded ? nil : 4)
                    .animation(.easeInOut(duration: 0.2), value: isBioExpanded)
                    .multilineTextAlignment(.leading)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isBioExpanded.toggle()
                    }
                } label: {
                    Text(isBioExpanded ? "Show less" : "Read more")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Known For

    private func knownForSection(_ works: [Result]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Known For")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(works.prefix(8), id: \.self) { result in
                        KnownForCard(
                            result: result,
                            isCurrentTitle: result.id == currentTitleID,
                            onDismissToCurrent: { dismiss() }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var initials: String {
        name.split(separator: " ").prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    private func formattedDate(_ raw: String) -> String? {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: raw) else { return nil }
        let output = DateFormatter()
        output.dateFormat = "MMM d, yyyy"
        return output.string(from: date)
    }

    private func age(from birthday: String) -> Int? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: birthday) else { return nil }
        return Calendar.current.dateComponents([.year], from: date, to: Date()).year
    }
}

// MARK: - Known For Card

/// Tap behaviour:
///   - When the card represents the title the user was already viewing
///     (`isCurrentTitle == true`), tapping just dismisses the sheet —
///     pushing a fresh details for the same title would be a no-op /
///     duplicate from the user's perspective.
///   - Otherwise, the card is a `NavigationLink(value: Result)` that
///     pushes onto the sheet's own NavigationStack, taking the user to
///     a full ContentDetailsView for that title without leaving the sheet.
private struct KnownForCard: View {

    let result: Result
    let isCurrentTitle: Bool
    let onDismissToCurrent: () -> Void

    private let cardWidth:  CGFloat = 90
    private let cardHeight: CGFloat = 135

    var body: some View {
        if isCurrentTitle {
            Button(action: onDismissToCurrent) {
                cardContent
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: result) {
                cardContent
            }
            .buttonStyle(.plain)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            KFImage.url(result.getResultPosterURL())
                .loadImmediately()
                .fromMemoryCacheOrRefresh()
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

            Text(result.getResultTitle())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: cardWidth, alignment: .leading)
        }
    }
}
