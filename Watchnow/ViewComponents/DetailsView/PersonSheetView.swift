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
}

// MARK: - Sheet

struct PersonSheetView: View {

    let personID:    Int
    let name:        String
    let profilePath: String?
    /// Pre-loaded from Cast.known_for / Result.known_for — shown with no
    /// extra network call. Optional: sections that can't supply it omit it.
    let knownFor: [Result]?

    @StateObject private var vm = PersonViewModel()
    @State private var isBioExpanded = false

    var body: some View {
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

                    if let works = knownFor, !works.isEmpty {
                        knownForSection(works)
                    }
                }
            }
            .padding(.bottom, 36)
        }
        .background(Color(.background))
        .task { await vm.fetch(id: personID) }
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
                        KnownForCard(result: result)
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

private struct KnownForCard: View {

    let result: Result
    private let cardWidth:  CGFloat = 90
    private let cardHeight: CGFloat = 135

    var body: some View {
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
