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
/// collection — the row badge (list) or the type glyph (grid) tells them
/// apart. Folders are the user's own collections ("Date Night",
/// "Halloween", …) and are picked from the album-card row below the nav
/// bar; creating, renaming and deleting them happens from that same row.
///
/// Titles are presented as a poster wall by default, with the older row
/// list one tap away in the toolbar. The grid is the better default for a
/// collection you already chose — the covers are the recognition cue, and
/// three across shows a dozen at once — while the list keeps the two
/// affordances a grid can't carry: edge swipes and drag-to-reorder.
struct WatchlistView: View {

    @ObservedObject var watchlistViewModel: WatchlistViewModel
    /// Observed here so the album row + filtered content refresh when
    /// folders are created/renamed/deleted or items move between them.
    @ObservedObject private var folderStore = FolderManager.shared
    /// The folder whose name is currently being edited in place, if any.
    /// Doubles as the flag for the icon strip below the row.
    @State private var editingFolderID: UUID?
    /// Working copy of the name while it's being typed. Committed on
    /// return; the folder itself already exists either way.
    @State private var draftName = ""
    @State private var moveTarget: Result?
    @ObservedObject private var syncStatus = SyncStatus.shared
    @Namespace private var navigationNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Survives relaunch: someone who prefers rows shouldn't have to say
    /// so every time they open the tab.
    @AppStorage("watchlistLayout") private var layoutRaw = WatchlistModel.Layout.grid.rawValue

    private var layout: WatchlistModel.Layout {
        WatchlistModel.Layout(rawValue: layoutRaw) ?? .grid
    }

    var body: some View {
        VStack(spacing: 0) {
            content
            syncFooter
        }
        .background(Color(.background))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isGlobalEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    layoutMenu
                }
            }
        }
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
        .confirmationDialog("Move to folder",
                            isPresented: Binding(
                                get: { moveTarget != nil },
                                set: { if !$0 { moveTarget = nil } }
                            ),
                            titleVisibility: .visible) {
            moveDialogButtons
        }
    }

    // MARK: - Layout menu

    /// View-options menu, the way Files and Photos do it.
    ///
    /// This replaced a hand-built two-segment capsule. That control was
    /// fine in isolation but wrong in a toolbar: it drew its own fill and
    /// its own selected pill, so on iOS 26 it sat *inside* the system's
    /// Liquid Glass bar as a second, flat, differently-shaded surface. A
    /// plain `Menu` inherits whatever the platform gives toolbar items —
    /// glass and its morph on 26, a standard bordered button before that —
    /// and an inline `Picker` renders the two options with a system
    /// checkmark, so the current mode is stated rather than implied by
    /// which half is tinted.
    private var layoutMenu: some View {
        Menu {
            Picker("Layout", selection: layoutSelection) {
                ForEach(WatchlistModel.Layout.allCases) { option in
                    Label(option.title, systemImage: option.symbol)
                        .tag(option)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: layout.symbol)
        }
        .accessibilityLabel("View options")
        .accessibilityValue(layout.title)
    }

    /// Bridges the menu's `Picker` to the persisted raw value, animating
    /// the swap on the way through so the grid/list cross-fade still runs
    /// when the change originates from a menu rather than a button.
    private var layoutSelection: Binding<WatchlistModel.Layout> {
        Binding(
            get: { layout },
            set: { newValue in
                guard newValue != layout else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
                    layoutRaw = newValue.rawValue
                }
            }
        )
    }

    // MARK: - Folder albums

    /// Album-card folder picker. Pinned above the content rather than
    /// scrolling with it: folders are the primary way this screen is
    /// navigated, and a filter you have to scroll back up to reach stops
    /// getting used.
    private var folderAlbums: some View {
        FolderAlbumRow(
            folders: folderStore.folders,
            allItems: watchlistViewModel.savedAll,
            posters: { watchlistViewModel.items(in: $0) },
            selected: watchlistViewModel.selectedFilter,
            onSelect: { selectFolder($0) },
            onRename: { beginEditing($0) },
            onDelete: { deleteFolder($0) },
            onNewFolder: { createAndEditFolder() },
            editingFolderID: editingFolderID,
            draftName: $draftName,
            onCommitName: { commitName() },
            onPickSymbol: { pickSymbol($0) },
            onDeleteEditing: { deleteEditingFolder() }
        )
        .background(Color(.background))
    }

    /// Picking a folder while another one's name is being typed commits
    /// that name first.
    ///
    /// A SwiftUI `Button` doesn't take keyboard focus, so tapping a
    /// neighbouring card left the field open and the rename uncommitted —
    /// the shelf ended up with a selected folder *and* a stray text field
    /// on a different card. Tapping elsewhere is how you finish naming
    /// something everywhere else, so it has to finish it here.
    private func selectFolder(_ filter: WatchlistModel.FolderFilter) {
        if editingFolderID != nil { commitName() }
        setFilter(filter)
    }

    private func setFilter(_ filter: WatchlistModel.FolderFilter) {
        // Quick and flat rather than springy: the album card's selection
        // plate springs between cards, but a spring on a cross-fading wall
        // of posters reads as a wobble.
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
            watchlistViewModel.setFilter(filter)
        }
    }

    // MARK: - Content dispatch

    @ViewBuilder
    private var content: some View {
        Group {
            if isGlobalEmpty {
                globalEmptyState
            } else {
                // One path whether the active folder has titles or not. An
                // earlier version pinned the picker above a standalone
                // empty state and put it inside the scroll view otherwise,
                // so moving between an empty folder and a full one
                // physically relocated the row and the whole screen lurched.
                savedItems(filteredItems)
            }
        }
        // Cross-dissolve between the two presentations. A
        // `matchedGeometryEffect` morph was tempting, but `List` virtualises
        // its rows and a lazy grid virtualises its cells, so the two never
        // agree on which views exist at the moment of the swap — the same
        // reason Files and Photos cross-fade this transition rather than
        // morphing it.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: layout)
    }

    /// The saved titles, with the folder picker riding along as the first
    /// thing inside whichever scroll view is on screen.
    ///
    /// It used to be pinned above the scroll view and collapse its own
    /// layout height on scroll. That was wrong twice over: every toggle
    /// relaid out the entire grid mid-gesture, and re-expanding it shrank
    /// the scroll view, which could nudge the content offset back into the
    /// very gesture that triggered the collapse — a feedback loop that read
    /// as stutter and jumping content. Letting the row scroll with the
    /// content removes the coupling completely: no height animation, no
    /// relayout, no offset to observe.
    @ViewBuilder
    private func savedItems(_ items: [Result]) -> some View {
        switch layout {
        case .grid:
            WatchlistGridView(items: items,
                              folderProvider: folderBadgeProvider,
                              onMoveToFolder: { moveTarget = $0 },
                              onRemove: { removeFromGrid($0) },
                              namespace: navigationNamespace,
                              contentID: watchlistViewModel.selectedFilter,
                              emptyState: AnyView(folderEmptyState)) {
                scrollingAlbums
            }
            .transition(folderChange)
        case .list:
            watchlistListView(items: items)
                .transition(folderChange)
        }
    }

    /// The folder row with its scroll choreography attached. Grid only —
    /// see the note in `watchlistListView` for why the list uses the plain
    /// row instead.
    ///
    /// Both effects are render-pass only — `scrollTransition` and
    /// `visualEffect` run during drawing and never write state, so a scroll
    /// costs no view updates at all. The previous version derived the same
    /// look from an `onScrollGeometryChange` handler writing `@State` on
    /// every frame, which re-rendered this whole screen (grid included)
    /// sixty times a second.
    @ViewBuilder
    private var scrollingAlbums: some View {
        if reduceMotion {
            folderAlbums
        } else {
            folderAlbums
                // Recedes as it leaves the top of the scroll view rather
                // than sliding flatly off. `bottomTrailing: .identity`
                // because this only ever exits upward — without it the row
                // renders mid-transition while sitting at rest.
                .scrollTransition(topLeading: .interactive,
                                  bottomTrailing: .identity,
                                  axis: .vertical) { view, phase in
                    view
                        .opacity(1 + phase.value)
                        .scaleEffect(1 + phase.value * 0.14, anchor: .top)
                        .blur(radius: -phase.value * 2.5)
                }
                // Stretches when the collection is dragged past the top.
                // Reads its own position rather than a published offset, so
                // the rubber band costs one transform and nothing else.
                .visualEffect { view, proxy in
                    let overscroll = max(0, proxy.frame(in: .scrollView).minY)
                    return view.scaleEffect(1 + min(overscroll, 140) / 1000,
                                            anchor: .top)
                }
        }
    }

    /// Grid-side removal. Wraps the view model call the way
    /// `GenericListView`'s trailing swipe does, so a title deleted from the
    /// poster wall collapses out of the grid and buzzes exactly like one
    /// deleted from the row list — the two routes shouldn't feel like
    /// different features.
    private func removeFromGrid(_ result: Result) {
        withAnimation(reduceMotion ? nil
                                   : .spring(response: 0.35, dampingFraction: 0.85)) {
            watchlistViewModel.remove(result)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Keying the content on the active filter makes a folder change a
    /// single content swap instead of dozens of individual cell insertions
    /// and removals animating past each other. It also puts the new folder
    /// at the top, which is where you want to be when you've just switched
    /// to it.
    private var folderChange: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .offset(y: 10))
    }

    /// Returns a per-item folder lookup only when the user is viewing
    /// the "All" set. Inside a specific folder every badge would be
    /// identical, which adds visual noise without conveying anything.
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
            // Plain row, not `scrollingAlbums`. A `List` treats its first
            // row as already sitting on the leading edge of the scroll
            // region, so `scrollTransition(topLeading: .interactive)`
            // reports a fully-transitioned phase at rest — the row kept its
            // height but rendered at opacity 0, which read as the folders
            // having disappeared from list mode entirely. The row still
            // scrolls away with the content here, which was the point; it
            // just doesn't get the fade on the way out.
            folderAlbums
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if items.isEmpty {
                folderEmptyState
                    .padding(.top, 40)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .id(watchlistViewModel.selectedFilter)
                    .transition(folderChange)
            }

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

            if !items.isEmpty {
                // A simple banner block at the foot of the list — same
                // treatment as the bottom of the home/details scroll pages.
                InlineBannerSection()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
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
                createAndEditFolder()
            }

            Button("Cancel", role: .cancel) {
                moveTarget = nil
            }
        }
    }

    // MARK: - In-place folder editing

    /// Creates the folder immediately, then drops its label into an inline
    /// text field.
    ///
    /// There's no create *form* any more. A modal asking for a name and an
    /// icon before the folder exists is a gate in front of a two-field
    /// decision; making the folder first and letting it be edited on the
    /// shelf is the Finder model, and it means the thing you're naming is
    /// visible while you name it. A folder left untouched is just an empty
    /// "New Folder" — one long-press from gone.
    private func createAndEditFolder() {
        let store = watchlistViewModel.folderStore
        let created = store.createFolder(name: "New Folder",
                                         symbol: Folder.defaultSymbol)
        setFilter(.folder(created.id))
        beginEditing(created, startEmpty: true)
    }

    /// `startEmpty` clears the field for a folder that was just made, so
    /// the first keystroke replaces the placeholder name instead of
    /// appending to it — the same thing Finder does by pre-selecting the
    /// text. Renaming an existing folder pre-fills, because there you're
    /// usually adjusting a name rather than replacing it.
    private func beginEditing(_ folder: Folder, startEmpty: Bool = false) {
        draftName = startEmpty ? "" : folder.name
        withAnimation(reduceMotion ? nil
                                   : .spring(response: 0.34, dampingFraction: 0.84)) {
            editingFolderID = folder.id
        }
    }

    /// Commits the typed name. An empty field leaves the previous name
    /// standing rather than creating a nameless folder — the card has to
    /// say something.
    private func commitName() {
        guard let id = editingFolderID else { return }
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            watchlistViewModel.folderStore.renameFolder(id: id, to: trimmed)
        }
        withAnimation(reduceMotion ? nil
                                   : .spring(response: 0.34, dampingFraction: 0.84)) {
            editingFolderID = nil
        }
    }

    /// Applied straight away — the card updates under the user's finger,
    /// which is the point of picking it on the shelf rather than in a form.
    private func pickSymbol(_ symbol: String) {
        guard let id = editingFolderID else { return }
        watchlistViewModel.folderStore.updateSymbol(id: id, to: symbol)
    }

    /// Discards the folder currently being edited.
    ///
    /// Creating a folder now makes it immediately, which means changing
    /// your mind has to be just as immediate — otherwise the only way out
    /// of a folder you didn't want was to name it, commit it, then hunt for
    /// the long-press menu. No confirmation: deleting a folder only unfiles
    /// its titles, it never removes anything from the watchlist.
    private func deleteEditingFolder() {
        guard let id = editingFolderID,
              let folder = folderStore.folders.first(where: { $0.id == id })
        else { return }

        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
            editingFolderID = nil
            deleteFolder(folder)
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

    /// Empty state for an active folder filter — the collection is
    /// non-empty overall, just empty inside the selected folder.
    @ViewBuilder
    private var folderEmptyState: some View {
        ContentUnavailableView {
            themedLabel(title: "Folder is empty",
                        systemImage: folderEmptyIcon,
                        tint: .accentColor)
        } description: {
            Text(folderEmptyHint)
        } actions: {
            Button("Show all") { setFilter(.all) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.accentColor)
        }
    }

    /// The route into a folder differs by layout — swipe in the list,
    /// long-press in the grid — so the hint has to say the right one or it
    /// sends the user looking for a gesture that isn't there.
    private var folderEmptyHint: String {
        switch layout {
        case .grid: return "Press and hold any saved poster, then tap Move to Folder."
        case .list: return "Swipe a saved title and tap Move to file it here."
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

    /// Quiet "Synced via iCloud" caption, pinned below the content. Shown
    /// only when the device is actually signed into iCloud, so it never
    /// claims a sync that isn't happening.
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
