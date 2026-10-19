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

        var title: String {
            switch self {
            case .similar:    return String(localized: "Similar", comment: "Picker: titles similar to this one")
            case .collection: return String(localized: "Collection", comment: "Picker: other films in the same collection")
            }
        }
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
            VStack(alignment: .leading, spacing: 12) {
                DetailsSectionHeader(title: sectionTitle) {
                    if hasBoth {
                        Picker("", selection: $mode.animation(.snappy)) {
                            ForEach(Mode.allCases) { m in
                                Text(m.title).tag(m)
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
                // A fresh row per mode, cross-faded, rather than one row
                // whose cards morph into other titles.
                .id(mode)
                .transition(.opacity)
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
        if hasBoth { return String(localized: "More like this") }
        if hasCollection, let name = collectionName { return name }
        return screenType == .tv
            ? String(localized: "Similar series", comment: "Details section title")
            : String(localized: "Similar movies", comment: "Details section title")
    }
}
