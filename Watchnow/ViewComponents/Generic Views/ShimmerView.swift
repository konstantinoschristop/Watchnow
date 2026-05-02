//
//  ShimmerView.swift
//  Watchnow
//
//  Single-animation shimmer: one @State phase lives in SkeletonContentView
//  and is shared to every ShimmerBox via Environment. One animation drives
//  all boxes in perfect sync — no GeometryReader, no blendMode, no per-box
//  @State — so the GPU only does one gradient sweep across the whole screen.
//

import SwiftUI

// MARK: - Environment key

private struct ShimmerPhaseKey: EnvironmentKey {
    static let defaultValue: CGFloat = -1
}

private extension EnvironmentValues {
    var shimmerPhase: CGFloat {
        get { self[ShimmerPhaseKey.self] }
        set { self[ShimmerPhaseKey.self] = newValue }
    }
}

// MARK: - ShimmerBox

/// Rounded rectangle in the system skeleton colour with a subtle gradient
/// sweep driven by the nearest ancestor's shimmer phase.
struct ShimmerBox: View {
    @Environment(\.shimmerPhase) private var phase
    var cornerRadius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.systemGray5))
            .overlay {
                // Gradient highlight centred at `phase`. UnitPoint values
                // outside [0,1] are valid — they place the band off-screen
                // before/after the sweep, clipping handles the rest.
                LinearGradient(
                    stops: [
                        .init(color: .clear,               location: 0.25),
                        .init(color: .white.opacity(0.12), location: 0.50),
                        .init(color: .clear,               location: 0.75),
                    ],
                    startPoint: UnitPoint(x: phase - 0.4, y: 0.5),
                    endPoint:   UnitPoint(x: phase + 0.4, y: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius,
                                            style: .continuous))
            }
    }
}

// MARK: - InlineShimmerContainer

/// Drop-in shimmer scope with a self-driving phase animation. Use this
/// anywhere you want shimmer placeholders *outside* of `SkeletonContentView`
/// (e.g. a small inline skeleton inside an actor sheet, a sheet header,
/// etc.). Identical look to the main feed skeleton — same sweep duration,
/// same gradient — just doesn't depend on the parent driving the phase.
struct InlineShimmerContainer<Content: View>: View {

    @ViewBuilder var content: () -> Content
    @State private var phase: CGFloat = -1

    var body: some View {
        content()
            .environment(\.shimmerPhase, phase)
            .onAppear {
                phase = -1
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

// MARK: - Skeleton cards

private struct SkeletonBottomCard: View {
    private let width:  CGFloat = 130
    private let radius: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ShimmerBox(cornerRadius: radius)
                .frame(width: width, height: 175)

            ShimmerBox(cornerRadius: 5)
                .frame(width: width * 0.85, height: 11)

            ShimmerBox(cornerRadius: 4)
                .frame(width: width * 0.55, height: 9)

            Spacer(minLength: 0)
        }
        .frame(width: width, height: 230)
    }
}

private struct SkeletonTopCard: View {
    private let width:  CGFloat = 180
    private let radius: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ShimmerBox(cornerRadius: radius)
                .frame(width: width, height: 112)

            ShimmerBox(cornerRadius: 5)
                .frame(width: width * 0.80, height: 11)

            ShimmerBox(cornerRadius: 4)
                .frame(width: width * 0.50, height: 9)

            Spacer(minLength: 0)
        }
        .frame(width: width, height: 165)
    }
}

// MARK: - Skeleton rows

private struct SkeletonCardRow: View {
    enum Kind { case top, bottom }
    let kind: Kind

    private var slotW:  CGFloat { kind == .bottom ? 150 : 232 }
    private var slotH:  CGFloat { kind == .bottom ? 295 : 215 }
    private var lead:   CGFloat { kind == .bottom ? 10  : 20  }
    private var gap:    CGFloat { kind == .bottom ? 5   : 0   }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: gap) {
                Spacer().frame(width: lead)
                ForEach(0..<5, id: \.self) { _ in
                    Group {
                        if kind == .bottom { SkeletonBottomCard() }
                        else               { SkeletonTopCard()    }
                    }
                    .frame(width: slotW, height: slotH)
                }
            }
        }
        .frame(height: slotH)
        .disabled(true)
        .allowsHitTesting(false)
    }
}

private struct SkeletonSection: View {
    let kind: SkeletonCardRow.Kind

    var body: some View {
        Section {
            SkeletonCardRow(kind: kind)
        } header: {
            HStack(spacing: 10) {
                ShimmerBox(cornerRadius: 6).frame(width: 26, height: 26)
                ShimmerBox(cornerRadius: 5).frame(width: 110, height: 13)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - SkeletonContentView

/// Full-screen skeleton for ContentMainView.
/// A single animation drives `phase` and injects it into the environment
/// so every ShimmerBox in the tree reads the same value — one sweep, zero
/// per-box @State.
struct SkeletonContentView: View {

    let sections: [ViewSections]
    @State private var phase: CGFloat = -1

    var body: some View {
        VStack(spacing: 0) {
            // Hero placeholder
            Color(.systemGray5)
                .containerRelativeFrame(.vertical) { h, _ in h * 0.75 }
                .ignoresSafeArea(edges: .top)

            // Genre chip row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { i in
                        ShimmerBox(cornerRadius: 20)
                            .frame(width: CGFloat(50 + (i % 3) * 15), height: 32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .disabled(true)

            LazyVStack(spacing: 6) {
                ForEach(sections, id: \.self) { section in
                    SkeletonSection(kind: section.isTopView ? .top : .bottom)
                }
            }
        }
        // Inject the single shared phase into the whole subtree.
        .environment(\.shimmerPhase, phase)
        .onAppear {
            phase = -1
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}
