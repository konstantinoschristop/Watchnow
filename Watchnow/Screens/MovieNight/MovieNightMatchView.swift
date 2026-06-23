//
//  MovieNightMatchView.swift
//  Watchnow
//
//  The payoff screen. If everyone liked the same title we celebrate the
//  top pick — shown as the swipe card that "won" — and offer to open its
//  details. If there was no unanimous winner we show the closest calls
//  instead. "Deal again" re-rolls a fresh deck; "Start over" returns to
//  setup. Styling mirrors the rest of the flow: accent-gradient primary
//  buttons, the poster-card hero, a celebratory accent badge.
//

import SwiftUI
import Kingfisher

struct MovieNightMatchView: View {

    @ObservedObject var vm: MovieNightViewModel
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let top = vm.topMatch {
                    header
                    heroCard(top)
                    actionRow(for: top)
                    if vm.matches.count > 1 {
                        posterRow(title: vm.playerCount > 1 ? "Everyone also liked" : "Also kept",
                                  results: Array(vm.matches.dropFirst()))
                    }
                } else {
                    noMatch
                }

                // One native ad at the foot of the match screen.
                NativeAdRow()
            }
            .padding(20)
        }
        .onAppear { appeared = true }
    }

    // MARK: - Match

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient.movieNightAccent)
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: appeared)
            }
            .frame(width: 64, height: 64)
            .shadow(color: .accentColor.opacity(0.4), radius: 12, y: 5)

            VStack(spacing: 4) {
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
    }

    /// The winning title as the same card used in the deck — so the payoff
    /// reads as "this is the card that won", with an accent glow.
    private func heroCard(_ result: Result) -> some View {
        SwipeCard(result: result)
            .frame(height: 440)
            .shadow(color: .accentColor.opacity(0.3), radius: 22, y: 10)
            .scaleEffect(appeared ? 1 : 0.96)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.82), value: appeared)
    }

    private func actionRow(for result: Result) -> some View {
        VStack(spacing: 12) {
            primaryButton("View details", icon: "info.circle.fill") {
                vm.detailTarget = result
            }
            HStack(spacing: 12) {
                secondaryButton("Deal again", icon: "arrow.triangle.2.circlepath") { vm.dealAgain() }
                secondaryButton("Start over", icon: "slider.horizontal.3") { vm.backToSetup() }
            }
        }
    }

    // MARK: - No match

    private var noMatch: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color(.secondarySystemBackground))
                    Image(systemName: "questionmark")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 64, height: 64)

                VStack(spacing: 4) {
                    Text("No unanimous pick")
                        .font(.title2.weight(.bold))
                    Text("Nobody landed on the same title — here's what came closest, or deal a fresh round.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if !vm.closestPicks.isEmpty {
                posterRow(title: "Closest calls", results: vm.closestPicks)
            }

            VStack(spacing: 12) {
                primaryButton("Deal again", icon: "arrow.triangle.2.circlepath") { vm.dealAgain() }
                secondaryButton("Start over", icon: "slider.horizontal.3") { vm.backToSetup() }
            }
        }
    }

    // MARK: - Poster row

    private func posterRow(title: String, results: [Result]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
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

    // MARK: - Buttons

    private func primaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background { LinearGradient.movieNightAccent }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .accentColor.opacity(0.4), radius: 12, y: 6)
        }
        .buttonStyle(MNPressableStyle())
    }

    private func secondaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
                )
        }
        .buttonStyle(MNPressableStyle())
    }
}

// MARK: - PosterThumb

/// Small tappable poster used in the "also liked" / "closest calls" rows.
private struct PosterThumb: View {

    let result: Result
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                KFImage.url(result.getPosterURL())
                    .resizable()
                    .scaledToFill()
                    .frame(width: 112, height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
                Text(result.getResultTitle())
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(width: 112, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}
