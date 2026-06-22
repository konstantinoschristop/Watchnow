//
//  WatchlistView.swift
//  Watchnow
//
//  Created by Konstantinos Christopoulos on 6/8/22.
//

import Foundation
import SwiftUI
import AlertToast

/// User's saved titles.
///
/// One axis of organisation: folders. Movies and TV series share a single
/// list — the MediaTypeBadge on each row distinguishes them. Folders are
/// the user's own collections ("Date Night", "Halloween", etc.) and live
/// in the chip row below the nav bar; their creation / rename / delete
/// lives in the nav-bar folders menu.
struct WatchlistView: View {

    @ObservedObject var watchlistViewModel: WatchlistViewModel
    /// Observed here so the chip row + filtered list refresh when folders
    /// are created/renamed/deleted or items move between folders.
    @ObservedObject private var folderStore = FolderManager.shared
    @State private var newFolderPresented = false
    @State private var folderToRename: Folder?
    @State private var moveTarget: Result?
    @State private var movieNightPresented = false
    @ObservedObject private var syncStatus = SyncStatus.shared
    @Namespace private var navigationNamespace

    var body: some View {
        VStack(spacing: 0) {
            if !isGlobalEmpty {
                folderChipsRow
            }
            content
            syncFooter
        }
        .background(Color(.background))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { watchlistViewModel.refreshDataIfNeeded() }
        .toast(isPresenting: $watchlistViewModel.showRemovedAlert) {
            AlertToast(displayMode: .alert,
                       type: .error(.red),
                       title: "Removed from Watchlist")
        }
        .toast(isPresenting: $watchlistViewModel.showAddedAlert) {
            AlertToast(displayMode: .alert,
                       type: .complete(.green),
                       title: "Added to Watchlist")
        }
        .sheet(isPresented: $newFolderPresented) {
            NewFolderSheet { name, symbol in
                let created = watchlistViewModel.folderStore.createFolder(name: name,
                                                                          symbol: symbol)
                watchlistViewModel.setFilter(.folder(created.id))
            }
        }
        .sheet(item: $folderToRename) { folder in
            NewFolderSheet(initial: folder) { name, symbol in
                watchlistViewModel.folderStore.renameFolder(id: folder.id, to: name)
                watchlistViewModel.folderStore.updateSymbol(id: folder.id, to: symbol)
            }
        }
        .confirmationDialog("Move to folder",
                            isPresented: Binding(
                                get: { moveTarget != nil },
                                set: { if !$0 { moveTarget = nil } }
                            ),
                            titleVisibility: .visible) {
            moveDialogButtons
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    movieNightPresented = true
                } label: {
                    Label("Movie Night", systemImage: "popcorn.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .fullScreenCover(isPresented: $movieNightPresented) {
            MovieNightView()
        }
    }

    // MARK: - Folder chips

    /// Two-row chip layout. "All" anchors row 1; folders split roughly in
    /// half between the rows. Row 2 gets extra leading padding so the
    /// stack reads as deliberately tilted/staggered. The "+ New folder"
    /// affordance is overlaid on the trailing edge so chips physically
    /// scroll under it — keeps the action always reachable without
    /// reading as "add to watchlist".
    private var folderChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            chipRows
                .padding(.leading, 16)
                // Reserve room on the trailing edge so the last chip
                // can scroll fully under the "+ New" overlay (28 fade
                // + 56 opaque block = 84pt) instead of butting up
                // against it.
                .padding(.trailing, 92)
                .padding(.vertical, 10)
        }
        .background(Color(.background))
        .overlay(alignment: .trailing) {
            newFolderOverlay
        }
    }

    /// Pinned "+" button overlaid on the trailing edge of the chip
    /// scroll. The leading fade + opaque trailing block span the FULL
    /// chip-area height so chips in either row are fully masked as they
    /// scroll behind — without this they'd be visible above and below
    /// the button itself.
    private var newFolderOverlay: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [Color(.background).opacity(0), Color(.background)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 28)

            Color(.background)
                .frame(width: 56)
                .overlay {
                    Button {
                        newFolderPresented = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.accentColor.opacity(0.12)))
                            .overlay(Circle().strokeBorder(Color.accentColor.opacity(0.35),
                                                           lineWidth: 0.5))
                    }
                    .accessibilityLabel("New folder")
                }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var chipRows: some View {
        let folders = watchlistViewModel.folderStore.folders
        let firstHalfCount = (folders.count + 1) / 2   // ceil(N/2)
        let firstHalf = Array(folders.prefix(firstHalfCount))
        let secondHalf = Array(folders.dropFirst(firstHalfCount))

        VStack(alignment: .leading, spacing: 8) {
            // Row 1 — always present, anchored by the "All" filter.
            HStack(spacing: 8) {
                FolderChip(label: "All",
                           symbol: "tray.full",
                           isSelected: watchlistViewModel.selectedFilter == .all) {
                    setFilter(.all)
                }
                ForEach(firstHalf) { folder in
                    folderChip(folder)
                }
            }

            // Row 2 — rendered only when there's a second half to show,
            // so the chip area collapses cleanly with few folders. Extra
            // leading padding gives the staggered/tilted look.
            if !secondHalf.isEmpty {
                HStack(spacing: 8) {
                    ForEach(secondHalf) { folder in
                        folderChip(folder)
                    }
                }
                .padding(.leading, 24)
            }
        }
    }

    @ViewBuilder
    private func folderChip(_ folder: Folder) -> some View {
        FolderChip(label: folder.name,
                   symbol: folder.symbol,
                   isSelected: watchlistViewModel.selectedFilter == .folder(folder.id)) {
            setFilter(.folder(folder.id))
        }
        .contextMenu {
            Button {
                folderToRename = folder
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleteFolder(folder)
            } label: {
                Label("Delete folder", systemImage: "trash")
            }
        }
    }

    private func setFilter(_ filter: WatchlistModel.FolderFilter) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            watchlistViewModel.setFilter(filter)
        }
    }

    // MARK: - Content dispatch

    @ViewBuilder
    private var content: some View {
        if isGlobalEmpty {
            globalEmptyState
        } else if filteredItems.isEmpty {
            folderEmptyState
        } else {
            watchlistListView(items: filteredItems)
        }
    }

    /// Returns a per-row folder lookup only when the user is viewing
    /// the "All" set. Inside a specific folder every row would carry the
    /// same badge, which adds visual noise without conveying anything.
    private var folderBadgeProvider: ((Int) -> Folder?)? {
        guard watchlistViewModel.selectedFilter == .all else { return nil }
        return { resultID in
            guard let folderID = folderStore.folderID(for: resultID) else { return nil }
            return folderStore.folders.first(where: { $0.id == folderID })
        }
    }

    private func watchlistListView(items: [Result]) -> some View {
        // `.onMove` on the inner ForEach gives long-press-to-drag in iOS
        // 16+ without requiring `editMode = .active`, which would also
        // turn on delete circles + intercept NavigationLink taps.
        List {
            GenericListView(results: .constant(items),
                            viewModel: watchlistViewModel,
                            namespace: navigationNamespace,
                            onMoveToFolder: { moveTarget = $0 },
                            onReorder: { source, destination in
                                watchlistViewModel.reorder(displayed: items,
                                                           from: source,
                                                           to: destination)
                            },
                            folderProvider: folderBadgeProvider)
        }
        .listStyle(.plain)
    }

    // MARK: - Move dialog

    @ViewBuilder
    private var moveDialogButtons: some View {
        if let target = moveTarget, let id = target.id {
            let currentFolderID = watchlistViewModel.folderStore.folderID(for: id)

            ForEach(watchlistViewModel.folderStore.folders) { folder in
                if folder.id != currentFolderID {
                    Button(folder.name) {
                        watchlistViewModel.folderStore.assign(resultID: id, to: folder.id)
                        moveTarget = nil
                    }
                }
            }

            if currentFolderID != nil {
                Button("Remove from folder") {
                    watchlistViewModel.folderStore.assign(resultID: id, to: nil)
                    moveTarget = nil
                }
            }

            Button("New folder…") {
                moveTarget = nil
                newFolderPresented = true
            }

            Button("Cancel", role: .cancel) {
                moveTarget = nil
            }
        }
    }

    private func deleteFolder(_ folder: Folder) {
        folderStore.deleteFolder(id: folder.id)
        if watchlistViewModel.selectedFilter == .folder(folder.id) {
            setFilter(.all)
        }
    }

    // MARK: - Empty states

    private var globalEmptyState: some View {
        ContentUnavailableView {
            themedLabel(title: "Your Watchlist is empty",
                        systemImage: "bookmark",
                        tint: .accentColor)
        } description: {
            Text("Tap the bookmark on any movie or TV series to save it here.")
        }
    }

    /// Empty state for an active folder filter — the list is non-empty
    /// overall, just empty inside the selected folder.
    @ViewBuilder
    private var folderEmptyState: some View {
        ContentUnavailableView {
            themedLabel(title: "Folder is empty",
                        systemImage: folderEmptyIcon,
                        tint: .accentColor)
        } description: {
            Text("Swipe a saved title and tap Move to file it here.")
        } actions: {
            Button("Show all") { setFilter(.all) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.accentColor)
        }
    }

    private var folderEmptyIcon: String {
        guard case let .folder(id) = watchlistViewModel.selectedFilter,
              let folder = watchlistViewModel.folderStore.folders.first(where: { $0.id == id })
        else { return "folder" }
        return folder.symbol
    }

    private func themedLabel(title: String,
                             systemImage: String,
                             tint: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
    }

    // MARK: - iCloud sync footer

    /// Quiet "Synced via iCloud" caption, pinned below the list. Shown only
    /// when the device is actually signed into iCloud, so it never claims a
    /// sync that isn't happening.
    @ViewBuilder
    private var syncFooter: some View {
        if syncStatus.isAvailable {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.icloud")
                    .font(.system(size: 11, weight: .medium))
                Text(syncCaption)
                    .font(.system(size: 12))
            }
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var syncCaption: String {
        guard let date = syncStatus.lastSyncedAt else { return "Synced via iCloud" }
        if Date().timeIntervalSince(date) < 5 {
            return "Synced via iCloud · just now"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Synced via iCloud · \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    // MARK: - Data shaping

    private var filteredItems: [Result] {
        watchlistViewModel.applyFolderFilter(watchlistViewModel.savedAll)
    }

    private var isGlobalEmpty: Bool {
        watchlistViewModel.savedAll.isEmpty
    }
}

// MARK: - FolderChip

/// Pill-shaped chip used in the folder filter row.
///
/// - `.standard` is the regular filter pill — filled accent when selected,
///   hairline-outlined when not.
/// - `.ghost` is a tinted accent outline used for the trailing "+ New"
///   action chip so it reads as a button, not as another folder.
private struct FolderChip: View {

    enum Style { case standard, ghost }

    let label: String
    let symbol: String
    let isSelected: Bool
    var style: Style = .standard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(background)
            }
            .overlay {
                Capsule()
                    .strokeBorder(borderColor, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var foreground: Color {
        switch style {
        case .standard: return isSelected ? .white : .primary
        case .ghost:    return .accentColor
        }
    }

    private var background: Color {
        switch style {
        case .standard: return isSelected ? .accentColor : Color(.secondarySystemBackground)
        case .ghost:    return .accentColor.opacity(0.1)
        }
    }

    private var borderColor: Color {
        switch style {
        case .standard: return isSelected ? .clear : .primary.opacity(0.08)
        case .ghost:    return .accentColor.opacity(0.35)
        }
    }
}

// MARK: - NewFolderSheet

/// Used for both create and edit. When `initial` is non-nil the sheet
/// pre-fills the name + selected symbol and uses "Save" as the primary
/// action instead of "Create".
private struct NewFolderSheet: View {

    var initial: Folder? = nil
    let onCommit: (_ name: String, _ symbol: String) -> Void

    @State private var name: String
    @State private var selectedSymbol: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    init(initial: Folder? = nil,
         onCommit: @escaping (_ name: String, _ symbol: String) -> Void) {
        self.initial = initial
        self.onCommit = onCommit
        _name = State(initialValue: initial?.name ?? "")
        _selectedSymbol = State(initialValue: initial?.symbol ?? Folder.defaultSymbol)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Folder name", text: $name)
                        .focused($nameFocused)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                             count: 4),
                              spacing: 8) {
                        ForEach(Folder.symbolPresets, id: \.self) { symbol in
                            symbolTile(symbol)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(initial == nil ? "New Folder" : "Edit Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(initial == nil ? "Create" : "Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onCommit(trimmed, selectedSymbol)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { nameFocused = true }
        }
        .presentationDetents([.medium])
    }

    private func symbolTile(_ symbol: String) -> some View {
        let isSelected = symbol == selectedSymbol
        return Button {
            selectedSymbol = symbol
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                }
        }
        .buttonStyle(.plain)
    }
}
