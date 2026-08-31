//
//  FolderAlbumRow.swift
//  Watchnow
//
//  Created by k.christopoulos on 31/8/26.
//

import SwiftUI

/// Folder picker for the watchlist, as a row of album cards.
///
/// Replaces the two-row pill strip that used to sit under the nav bar.
/// Pills scaled badly: past three or four folders they wrapped into a
/// staggered double row with a pinned "+" button overlaying the trailing
/// edge, and a folder full of titles looked exactly like an empty one.
/// An album card shows a fan of the covers actually inside it, so the
/// folder is identifiable at a glance by its contents rather than by a
/// name you have to read.
struct FolderAlbumRow: View {

    let folders: [Folder]
    /// Every saved title, newest first — the "All" card fans the first
    /// few of these.
    let allItems: [Result]
    /// Covers for a given folder, newest first. Supplied by the caller so
    /// this view never has to know how membership is stored.
    let posters: (Folder) -> [Result]
    let selected: WatchlistModel.FolderFilter
    let onSelect: (WatchlistModel.FolderFilter) -> Void
    let onRename: (Folder) -> Void
    let onDelete: (Folder) -> Void
    let onNewFolder: () -> Void
    /// The folder being renamed in place, if any. Its card swaps its label
    /// for a text field and the icon strip slides in beneath the row.
    var editingFolderID: UUID? = nil
    var draftName: Binding<String> = .constant("")
    var onCommitName: () -> Void = {}
    var onPickSymbol: (String) -> Void = { _ in }
    var onDeleteEditing: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace
    @Namespace private var symbolNamespace

    private var isEditing: Bool { editingFolderID != nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        allCard

                        ForEach(folders) { folder in
                            folderCard(folder)
                                .id(folder.id)
                        }

                        if !isEditing {
                            newFolderCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollClipDisabled()
                // A folder created at the end of a long row would otherwise
                // be named off-screen.
                .onChange(of: editingFolderID) { _, id in
                    guard let id else { return }
                    withAnimation(reduceMotion ? nil : .spring(response: 0.4,
                                                               dampingFraction: 0.85)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }

            if isEditing {
                symbolStrip
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }

    // MARK: - Icon strip

    /// The icon choices, shown only while a folder is being edited.
    ///
    /// Lives on the shelf rather than in a form: tapping one applies it to
    /// the card a few points above, so the choice is made against the thing
    /// it changes instead of against a preview of it.
    private var symbolStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Folder.symbolPresets, id: \.self) { symbol in
                    symbolButton(symbol)
                }

                // Separated from the icons by a rule: it belongs to the
                // same editing session but it isn't another choice of look,
                // and sitting flush against the symbols it would be one
                // mis-tap away from a folder you meant to decorate.
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 0.5, height: 26)
                    .padding(.horizontal, 4)

                deleteButton
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    /// Discards the folder being edited. Present only during an edit,
    /// which is when changing your mind is most likely — the folder now
    /// exists from the moment you tap New.
    private var deleteButton: some View {
        Button(action: onDeleteEditing) {
            Image(systemName: "trash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 40, height: 40)
                .background {
                    Circle().fill(Color.red.opacity(0.12))
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete folder")
    }

    private func symbolButton(_ symbol: String) -> some View {
        let isSelected = editingSymbol == symbol

        return Button {
            onPickSymbol(symbol)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 40, height: 40)
                .background {
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "symbolPick", in: symbolNamespace)
                    } else {
                        Circle().fill(Color(.tertiarySystemFill))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var editingSymbol: String? {
        guard let editingFolderID else { return nil }
        return folders.first(where: { $0.id == editingFolderID })?.symbol
    }

    // MARK: - Cards

    private var allCard: some View {
        FolderAlbumCard(title: "All",
                        count: allItems.count,
                        fallbackSymbol: "tray.full",
                        covers: Array(allItems.prefix(3)),
                        isSelected: selected == .all,
                        namespace: selectionNamespace,
                        reduceMotion: reduceMotion) {
            onSelect(.all)
        }
    }

    private func folderCard(_ folder: Folder) -> some View {
        let contents = posters(folder)
        return FolderAlbumCard(title: folder.name,
                               count: contents.count,
                               fallbackSymbol: folder.symbol,
                               covers: Array(contents.prefix(3)),
                               isSelected: selected == .folder(folder.id),
                               namespace: selectionNamespace,
                               reduceMotion: reduceMotion,
                               editingName: editingFolderID == folder.id ? draftName : nil,
                               onSubmitName: onCommitName) {
            onSelect(.folder(folder.id))
        }
        .contextMenu {
            Button {
                onRename(folder)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete(folder)
            } label: {
                Label("Delete folder", systemImage: "trash")
            }
        }
    }

    /// Trailing "create" card. A dashed outline rather than a filled tile
    /// so it reads as an empty slot to fill, not as another folder that
    /// happens to have no covers.
    private var newFolderCard: some View {
        Button(action: onNewFolder) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: FolderAlbumCard.cornerRadius,
                                 style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.35),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(width: FolderAlbumCard.width,
                           height: FolderAlbumCard.coverHeight)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                Text("New")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text(" ")
                    .font(.system(size: 11))
                    .hidden()
            }
            .frame(width: FolderAlbumCard.width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New folder")
    }
}

// MARK: - FolderAlbumCard

/// One album, as a control: a `FolderAlbumFace` wrapped in a button.
struct FolderAlbumCard: View {

    let title: String
    let count: Int
    let fallbackSymbol: String
    let covers: [Result]
    let isSelected: Bool
    let namespace: Namespace.ID
    let reduceMotion: Bool
    /// Non-nil while this folder's name is being edited in place.
    var editingName: Binding<String>? = nil
    var onSubmitName: () -> Void = {}
    let action: () -> Void

    static let width: CGFloat = FolderAlbumFace.width
    static let coverHeight: CGFloat = FolderAlbumFace.coverHeight
    static let cornerRadius: CGFloat = FolderAlbumFace.cornerRadius

    var body: some View {
        if let editingName {
            // No button while editing: the card's job for those few seconds
            // is to hold a text field, and a tap on it should place the
            // caret rather than re-select the folder.
            FolderAlbumFace(title: title,
                            count: count,
                            fallbackSymbol: fallbackSymbol,
                            covers: covers,
                            isSelected: true,
                            namespace: namespace,
                            editingName: editingName,
                            onSubmitName: onSubmitName)
        } else {
            Button(action: action) {
                FolderAlbumFace(title: title,
                                count: count,
                                fallbackSymbol: fallbackSymbol,
                                covers: covers,
                                isSelected: isSelected,
                                namespace: namespace)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AlbumPressStyle(reduceMotion: reduceMotion))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title), \(count) titles")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        }
    }
}

// MARK: - FolderAlbumFace

/// The look of an album — a fan of up to three covers, the folder's name,
/// and how many titles are inside — with no interaction attached.
///
/// Split out from `FolderAlbumCard` so the folder editor can show a live
/// preview of the folder being created. Rendering the card itself there
/// would have put a button on screen that looks tappable and does nothing,
/// which is exactly the affordance mistake the watchlist redesign set out
/// to remove.
struct FolderAlbumFace: View {

    let title: String
    let count: Int
    /// Drawn when the folder has no covers to fan — the icon the user
    /// picked for it, so an empty folder is still recognisably itself.
    let fallbackSymbol: String
    let covers: [Result]
    var isSelected: Bool = false
    let namespace: Namespace.ID
    /// When non-nil the title becomes an inline, auto-focused text field.
    var editingName: Binding<String>? = nil
    var onSubmitName: () -> Void = {}

    static let width: CGFloat = 104
    static let coverHeight: CGFloat = 84
    static let cornerRadius: CGFloat = 12

    /// Covers are 2:3, sized to the card's height.
    private var posterWidth: CGFloat { Self.coverHeight * 2 / 3 }

    var body: some View {
        VStack(spacing: 8) {
            coverStack

            if let editingName {
                InlineFolderNameField(text: editingName, onSubmit: onSubmitName)
            } else {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .lineLimit(1)
            }

            Text(count == 1 ? "1 title" : "\(count) titles")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                // Tabular figures so the caption doesn't shuffle sideways
                // as counts change under it.
                .monospacedDigit()
        }
        .frame(width: Self.width)
    }

    // MARK: Cover fan

    /// Up to three covers splayed behind each other. Back cards are rotated
    /// and pushed sideways so the stack reads as a physical pile — a plain
    /// grid of three thumbnails at this size just looks like a broken
    /// layout.
    private var coverStack: some View {
        ZStack {
            selectionPlate

            if covers.isEmpty {
                emptyPlate
            } else {
                ForEach(Array(covers.enumerated().reversed()), id: \.element) { index, result in
                    poster(result)
                        .rotationEffect(.degrees(rotation(for: index)))
                        .offset(x: offset(for: index))
                        .zIndex(Double(covers.count - index))
                }
            }
        }
        .frame(width: Self.width, height: Self.coverHeight)
    }

    /// Rounded accent plate behind the fan, drawn only for the active
    /// folder. `matchedGeometryEffect` slides it between cards instead of
    /// blinking off one and on to the next.
    @ViewBuilder
    private var selectionPlate: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: Self.cornerRadius + 4, style: .continuous)
                .fill(Color.accentColor.opacity(0.14))
                .overlay {
                    RoundedRectangle(cornerRadius: Self.cornerRadius + 4, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
                }
                .frame(width: Self.width, height: Self.coverHeight)
                .matchedGeometryEffect(id: "folderSelection", in: namespace)
        }
    }

    private var emptyPlate: some View {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            .fill(Color(.tertiarySystemFill))
            .frame(width: posterWidth, height: Self.coverHeight - 14)
            .overlay {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
    }

    private func poster(_ result: Result) -> some View {
        PosterImage(url: result.getResultPosterURL(),
                    width: posterWidth * 2,
                    height: (Self.coverHeight - 14) * 2,
                    cornerRadius: 8,
                    shadowRadius: 0)
            .frame(width: posterWidth, height: Self.coverHeight - 14)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
    }

    /// Front cover sits square; the two behind it lean outward.
    private func rotation(for index: Int) -> Double {
        switch index {
        case 1:  return -9
        case 2:  return 9
        default: return 0
        }
    }

    private func offset(for index: Int) -> CGFloat {
        switch index {
        case 1:  return -18
        case 2:  return 18
        default: return 0
        }
    }
}

// MARK: - InlineFolderNameField

/// The album card's label, as an editable field.
///
/// Its own view so it can own a `@FocusState` and take focus in
/// `onAppear` — the field only exists while a folder is being renamed, so
/// appearing and needing focus are the same moment. Sized and styled to
/// sit exactly where the static label does, so the card doesn't jump when
/// editing starts or ends.
private struct InlineFolderNameField: View {
    @Binding var text: String
    let onSubmit: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        TextField("Name", text: $text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($focused)
            .onSubmit(onSubmit)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            }
            .onAppear { focused = true }
            // Tapping away from the card ends the rename, which is what the
            // gesture means everywhere else a field like this appears.
            .onChange(of: focused) { _, isFocused in
                if !isFocused { onSubmit() }
            }
    }
}

// MARK: - AlbumPressStyle

/// Press feedback for an album card. Scales the whole card rather than
/// dimming it — an album is a physical-feeling object, and a push is the
/// gesture that matches.
private struct AlbumPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}
