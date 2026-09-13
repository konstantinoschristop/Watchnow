//
//  ProviderPickerGrid.swift
//  Watchnow
//
//  "Which services do you have?" — as a wrapping row of logo chips.
//
//  Shared by onboarding's first step and the Settings screen, which is the
//  whole reason it exists as its own file: the same question asked twice,
//  answered into the same `StreamingPreferences`, should not be two pieces
//  of layout that can drift apart. Movie Night's setup screen keeps its own
//  chips — they carry that screen's motion — but reads the same curated
//  catalogue from `StreamingProviderCatalog`.
//

import SwiftUI
import Kingfisher

struct ProviderPickerGrid: View {

    let providers: [WatchProvider]
    let selectedIDs: Set<Int>
    let onToggle: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FlowLayout(spacing: 10) {
            ForEach(providers) { provider in
                chip(for: provider)
            }
        }
    }

    private func chip(for provider: WatchProvider) -> some View {
        let isSelected = selectedIDs.contains(provider.provider_id)

        return Button {
            withAnimation(reduceMotion ? nil : AppMotion.springSnappy) {
                onToggle(provider.provider_id)
            }
        } label: {
            HStack(spacing: 8) {
                logo(for: provider)
                Text(provider.provider_name)
                    .appFont(15, weight: .semibold, relativeTo: .subheadline)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(minHeight: AppTouch.minTarget)
            .background {
                AppRadius.shape(AppRadius.panel)
                    .fill(isSelected ? AnyShapeStyle(Color.accentColor)
                                     : AnyShapeStyle(Color(.secondarySystemBackground)))
            }
            .overlay {
                AppRadius.shape(AppRadius.panel)
                    .strokeBorder(isSelected ? Color.clear : Color.primary.opacity(0.08),
                                  lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // One control, one state. Without this VoiceOver reads the logo and
        // the name as separate elements and never says whether it is on.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(provider.provider_name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The service's own mark, which is how people recognise a subscription
    /// far faster than by its name. Falls back to a neutral glyph rather
    /// than a gap when TMDB has no logo.
    @ViewBuilder
    private func logo(for provider: WatchProvider) -> some View {
        if let url = provider.logoURL {
            KFImage(url)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .clipShape(AppRadius.shape(AppRadius.small))
        } else {
            Image(systemName: "play.tv")
                .appFont(14, weight: .semibold, relativeTo: .subheadline)
                .frame(width: 22, height: 22)
        }
    }
}
