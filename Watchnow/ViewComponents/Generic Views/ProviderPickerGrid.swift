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
    /// Drives the cascade when this appears inside onboarding. Settings
    /// leaves it at its default, so the section simply exists — a list that
    /// animates itself in every time you open Settings is a tic, not a
    /// flourish.
    var revealed: Bool = true
    var reduceMotionOverride: Bool? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotionEnvironment
    private var reduceMotion: Bool { reduceMotionOverride ?? reduceMotionEnvironment }
    @Environment(\.dynamicTypeSize) private var typeSize

    /// A chip is a compact-size affordance: it sizes to its own text, and
    /// "Amazon Prime Video" at an accessibility size is wider than the
    /// phone. Past that point the same controls become full-width rows,
    /// which have somewhere to grow into.
    private var usesRows: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        if usesRows {
            VStack(spacing: 8) {
                ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                    chip(for: provider)
                        .staggeredReveal(index: index, isRevealed: revealed, reduceMotion: reduceMotion)
                }
            }
        } else {
            FlowLayout(spacing: 10) {
                ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                    chip(for: provider)
                        .staggeredReveal(index: index, isRevealed: revealed, reduceMotion: reduceMotion)
                }
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
                    .lineLimit(usesRows ? 2 : 1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: usesRows)
                if usesRows {
                    Spacer(minLength: 8)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .appFont(18, weight: .semibold, relativeTo: .body)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: usesRows ? .infinity : nil, alignment: .leading)
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
                // Without a placeholder the chip shows a 22pt hole for as
                // long as the logo takes to arrive, and on a first run with
                // a cold cache that is every chip at once — which reads as
                // broken rather than as loading.
                .placeholder {
                    AppRadius.shape(AppRadius.small)
                        .fill(Color.primary.opacity(0.06))
                }
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
