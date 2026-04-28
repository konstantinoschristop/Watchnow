//
//  MoreLikeThisSection.swift
//  Watchnow
//
//  A single section that merges "Similar" + "Collection" discovery content
//  behind a segmented picker, when both exist. Falls back to just Similar
//  (or just Collection) when only one is available.
//

import SwiftUI

struct MoreLikeThisSection: View {

    enum Mode: String, CaseIterable, Identifiable {
        case similar    = "Similar"
        case collection = "Collection"
        var id: String { rawValue }
    }

    let similars: [Result]
    let collection: [Result]
    let collectionName: String?
    let screenType: ScreenTypes
    let namespace: Namespace.ID

    @State private var mode: Mode = .similar

    private var hasSimilars: Bool { !similars.isEmpty }
    private var hasCollection: Bool { !collection.isEmpty }
    private var hasBoth: Bool { hasSimilars && hasCollection }

    var body: some View {
        if hasSimilars || hasCollection {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeaderView(
                    title: sectionTitle,
                    subtitle: sectionSubtitle,
                    icon: sectionIcon,
                    tint: sectionTint
                ) {
                    if hasBoth {
                        Picker("", selection: $mode) {
                            ForEach(Mode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                }

                SimilarsView(
                    content: currentContent,
                    screenType: screenType,
                    namespace: namespace
                )
            }
            .onAppear {
                // If only one of the two exists, make sure the picker mode
                // reflects what's actually being shown.
                if !hasSimilars, hasCollection { mode = .collection }
                else if hasSimilars, !hasCollection { mode = .similar }
            }
        }
    }

    private var currentContent: [Result] {
        if hasBoth {
            return mode == .similar ? similars : collection
        }
        return hasSimilars ? similars : collection
    }

    private var sectionTitle: String {
        if hasBoth { return "More like this" }
        if hasCollection, let name = collectionName { return name }
        return "Similar \(screenType.rawValue)"
    }

    private var sectionSubtitle: String? {
        if hasBoth { return nil }
        if hasCollection { return "Parts of the collection" }
        return "You might also like"
    }

    /// Icon flips between grid (similar / mixed) and film reel (collection-
    /// only) so the glyph gives a second visual cue about what's in the row
    /// before the user reads the title.
    private var sectionIcon: String {
        if hasBoth { return "square.grid.2x2.fill" }
        if hasCollection { return "film.stack.fill" }
        return "square.grid.2x2.fill"
    }

    /// Accent for mixed/similar, indigo for collection-only — the collection
    /// gets its own colour so a user flipping between details screens can
    /// tell at a glance "this title is part of a franchise" just from the
    /// header tint.
    /// Always the accent — colour-coding "this is a collection" vs
    /// "more like this" was visual noise once the rest of the app
    /// settled on a single accent palette. The icon (a different SF
    /// Symbol per mode) still carries the differentiation.
    private var sectionTint: Color { .accentColor }
}
