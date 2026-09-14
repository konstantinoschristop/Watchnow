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

    /// How the chips are painted. The layout, the behaviour and the
    /// accessibility are shared either way — only the surface differs,
    /// which is the whole point of keeping this one component: Settings
    /// and onboarding ask the same question and must not drift apart in
    /// how they *answer* it.
    enum Style {
        /// Settings: a grouped control on a system background.
        case standard
        /// Onboarding: glass over the drifting poster wall. Deliberately
        /// not a material — the wall behind redraws continuously, and a
        /// material over it would re-blur on every one of those frames.
        case cinema
    }

    let providers: [WatchProvider]
    let selectedIDs: Set<Int>
    let onToggle: (Int) -> Void
    /// Drives the cascade when this appears inside onboarding. Settings
    /// leaves it at its default, so the section simply exists — a list that
    /// animates itself in every time you open Settings is a tic, not a
    /// flourish.
    var revealed: Bool = true
    var reduceMotionOverride: Bool? = nil
    var style: Style = .standard

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
            .foregroundStyle(foreground(isSelected: isSelected))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: usesRows ? .infinity : nil, alignment: .leading)
            .frame(minHeight: AppTouch.minTarget)
            .background {
                AppRadius.shape(AppRadius.panel)
                    .fill(fill(isSelected: isSelected))
            }
            .overlay {
                AppRadius.shape(AppRadius.panel)
                    .strokeBorder(stroke(isSelected: isSelected), lineWidth: 1)
            }
            // Selected chips lift out of the sheet and glow, so a row of
            // them reads as chosen at a glance rather than only by colour.
            //
            // Cinema only, along with the haptic below. Settings shares this
            // component but was not part of the onboarding redesign, and its
            // chips are deliberately left exactly as they were — a shared
            // control is allowed to have two surfaces, not two behaviours
            // nobody asked for.
            .scaleEffect(isCinema && isSelected && !reduceMotion ? 1.03 : 1)
            .shadow(color: Color.accentColor.opacity(isCinema && isSelected ? 0.45 : 0),
                    radius: isCinema ? 12 : 0, y: 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(trigger: isSelected) { _, _ in isCinema ? .selection : nil }
        // One control, one state. Without this VoiceOver reads the logo and
        // the name as separate elements and never says whether it is on.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(provider.provider_name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Surface

    private var isCinema: Bool { style == .cinema }

    private func foreground(isSelected: Bool) -> Color {
        switch style {
        case .standard: return isSelected ? .white : .primary
        case .cinema:   return isSelected ? .white : .white.opacity(0.86)
        }
    }

    private func fill(isSelected: Bool) -> AnyShapeStyle {
        switch style {
        case .standard:
            return isSelected ? AnyShapeStyle(Color.accentColor)
                              : AnyShapeStyle(Color(.secondarySystemBackground))
        case .cinema:
            return isSelected
                ? AnyShapeStyle(LinearGradient(colors: [Color.accentColor, WatchnowBrand.blue],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(OnboardingSurface.glass)
        }
    }

    private func stroke(isSelected: Bool) -> Color {
        switch style {
        case .standard: return isSelected ? .clear : .primary.opacity(0.08)
        case .cinema:   return isSelected ? .white.opacity(0.35) : OnboardingSurface.edge
        }
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
                        .fill(isCinema ? Color.white.opacity(0.14)
                                   : Color.primary.opacity(0.06))
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
