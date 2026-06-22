//
//  MovieNightMatchView.swift
//  Watchnow
//
//  The payoff screen. If everyone liked the same title we celebrate the
//  top pick and offer to open its details. If there was no unanimous
//  winner we show the closest calls instead. Either way "Deal again"
//  re-rolls a fresh deck and "Start over" returns to the setup screen.
//

import SwiftUI
import Kingfisher

struct MovieNightMatchView: View {

    @ObservedObject var vm: MovieNightViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let top = vm.topMatch {
                    matchHeader
                    heroCard(top)
                    actionRow(for: top)
                    if vm.matches.count > 1 {
                        alsoLiked(Array(vm.matches.dropFirst()))
                    }
                } else {
                    noMatch
                }
            }
            .padding(20)
        }
    }

    // MARK: - Match

    private var matchHeader: some View {
        VStack(spacing: 6) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 34))
                .foregroundStyle(.accent)
            Text(vm.playerCount > 1 ? "It's a match!" : "Your pick tonight")
                .font(.title.weight(.bold))
            Text(vm.playerCount > 1
                 ? "Everyone wants to watch this one."
                 : "Top of the titles you kept.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    private func heroCard(_ result: Result) -> some View {
        VStack(spacing: 14) {
            KFImage.url(result.getPosterURL())
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)

            Text(result.getResultTitle())
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                let year = result.getReleaseDate(addSeparator: false)
                if !year.isEmpty { Text(year) }
                if let rating = result.vote_average, rating > 0 {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            if let overview = result.overview, !overview.isEmpty {
                Text(overview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
            }
        }
    }

    private func actionRow(for result: Result) -> some View {
        VStack(spacing: 10) {
            Button {
                vm.detailTarget = result
            } label: {
                Label("View details", systemImage: "info.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: 10) {
                Button { vm.dealAgain() } label: {
                    Label("Deal again", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.bordered)

                Button { vm.backToSetup() } label: {
                    Label("Start over", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func alsoLiked(_ results: [Result]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(vm.playerCount > 1 ? "Everyone also liked" : "Also kept")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(results, id: \.id) { result in
                        PosterThumb(result: result) { vm.detailTarget = result }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - No match

    private var noMatch: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "person.2.slash.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("No unanimous pick")
                    .font(.title2.weight(.bold))
                Text("Nobody landed on the same title. Here's what came closest — or deal a fresh round.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !vm.closestPicks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(vm.closestPicks, id: \.id) { result in
                            PosterThumb(result: result) { vm.detailTarget = result }
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button { vm.dealAgain() } label: {
                    Label("Deal again", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)

                Button { vm.backToSetup() } label: {
                    Label("Start over", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - PosterThumb

/// Small tappable poster used in the "also liked" / "closest" rows.
private struct PosterThumb: View {

    let result: Result
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                KFImage.url(result.getPosterURL())
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 165)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(result.getResultTitle())
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(width: 110, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}
