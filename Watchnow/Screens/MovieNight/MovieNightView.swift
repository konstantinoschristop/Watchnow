//
//  MovieNightView.swift
//  Watchnow
//
//  Container for the Movie Night flow. Owns the view model and swaps in
//  the right screen for the current `phase`, wrapped in its own
//  NavigationStack so the results screen can push a details page even
//  though the whole flow is presented modally (full-screen cover).
//

import SwiftUI

struct MovieNightView: View {

    @StateObject private var vm = MovieNightViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.background).ignoresSafeArea()
                content
            }
            .navigationTitle("Movie Night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .accessibilityLabel("Close")
                }
            }
            .navigationDestination(item: $vm.detailTarget) { result in
                let model = ContentDetailsModel(screenType: .movie, result: result)
                ContentDetailsView(detailsViewModel: ContentDetailsViewModel(model: model))
            }
            // The app's only fullscreen ad. Warmed up while the user swipes
            // so it's instant, and shown once the session completes — a real
            // "you're done" boundary rather than an interruption. Frequency
            // caps and the no-creative case are handled by the manager.
            .onChange(of: vm.phase) { _, phase in
                switch phase {
                case .swiping: InterstitialAdManager.shared.preload()
                case .results: InterstitialAdManager.shared.presentIfAllowed()
                default: break
                }
            }
        }
        .modifier(SoftScrollEdgeEffectStyleModifier())
    }

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .setup:    MovieNightSetupView(vm: vm)
        case .loading:  loadingView
        case .swiping:  MovieNightSwipeView(vm: vm)
        case .results:  MovieNightMatchView(vm: vm)
        case .empty:    emptyView
        case .error:    errorView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Rounding up tonight's contenders…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("Nothing fit that combo", systemImage: "popcorn")
        } description: {
            Text("Try fewer filters or a different mood.")
        } actions: {
            Button("Back to setup") { vm.backToSetup() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var errorView: some View {
        ContentUnavailableView {
            Label("Couldn't load picks", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Check your connection and try again.")
        } actions: {
            Button("Back to setup") { vm.backToSetup() }
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Shared style

extension LinearGradient {
    /// The Movie Night accent sweep (light → dark accent). Shared by the
    /// setup CTA and the match-screen buttons so the whole flow reads as one.
    static var movieNightAccent: LinearGradient {
        LinearGradient(
            colors: [Color.accentColor.mix(with: .white, by: 0.10),
                     Color.accentColor.mix(with: .black, by: 0.20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
