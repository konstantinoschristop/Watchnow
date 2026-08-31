//
//  FolderManager.swift
//  Watchnow
//
//  User-defined collections for the watchlist. Each saved title can live in
//  at most one folder; titles not in any folder are "Uncategorized". The
//  store is split into two persisted blobs:
//
//    - `folders`: the user's folder definitions (`Folder`).
//    - `membership`: a `[String: UUID]` map of TMDB-id → folder-id. Stored
//      with string keys so the on-disk JSON is a plain dictionary (the
//      alternative `[Int: UUID]` encodes as an unkeyed array of alternating
//      key/value pairs — round-trippable but harder to inspect).
//
//  Both are mirrored in `@Published` properties so SwiftUI views observing
//  `FolderManager.shared` re-render when the user creates a folder, renames
//  one, or moves an item.
//

import Foundation

/// User-defined collection within the watchlist.
struct Folder: Identifiable, Codable, Hashable {

    let id: UUID
    var name: String
    /// SF Symbol name shown as the folder's icon. Defaults to "folder".
    var symbol: String
    let createdAt: Date

    static let defaultSymbol = "folder"

    /// Curated SF Symbol set surfaced in the folder editor's icon picker.
    ///
    /// Twelve, laid out as two rows of six. The previous eight were mostly
    /// abstract marks — a folder, a star, a bolt — which made two folders
    /// hard to tell apart at album-card size. These lean on the kinds of
    /// collection people actually make: a night in, a genre, a mood.
    static let symbolPresets = [
        "folder",
        "film.fill",
        "tv.fill",
        "popcorn.fill",
        "heart.fill",
        "star.fill",
        "sparkles",
        "moon.stars.fill",
        "flame.fill",
        "theatermasks.fill",
        "crown.fill",
        "bolt.fill"
    ]
}

@MainActor
final class FolderManager: ObservableObject {

    static let shared = FolderManager()

    @Published private(set) var folders: [Folder]
    /// TMDB-id (as String) → folder-id. Items absent from the map are
    /// Uncategorized.
    @Published private(set) var membership: [String: UUID]

    private nonisolated static let foldersKey = "watchlist_folders"
    private nonisolated static let membershipKey = "watchlist_folder_membership"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.foldersKey),
           let decoded = try? JSONDecoder().decode([Folder].self, from: data) {
            self.folders = decoded
        } else {
            self.folders = []
        }

        if let data = UserDefaults.standard.data(forKey: Self.membershipKey),
           let decoded = try? JSONDecoder().decode([String: UUID].self, from: data) {
            self.membership = decoded
        } else {
            self.membership = [:]
        }

        // Reload + republish when folders/membership arrive from another
        // device via iCloud.
        NotificationCenter.default.addObserver(
            forName: CloudSync.didMergeRemoteChanges,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let keys = note.userInfo?[CloudSync.changedKeysKey] as? [String] ?? []
            guard keys.contains(Self.foldersKey) || keys.contains(Self.membershipKey) else { return }
            Task { @MainActor in self?.reloadFromStore() }
        }
    }

    // MARK: - Folder CRUD

    @discardableResult
    func createFolder(name: String,
                      symbol: String = Folder.defaultSymbol) -> Folder {
        let folder = Folder(id: UUID(),
                            name: name,
                            symbol: symbol,
                            createdAt: Date())
        folders.append(folder)
        persistFolders()
        return folder
    }

    func renameFolder(id: UUID, to newName: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].name = newName
        persistFolders()
    }

    func updateSymbol(id: UUID, to newSymbol: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].symbol = newSymbol
        persistFolders()
    }

    func deleteFolder(id: UUID) {
        folders.removeAll { $0.id == id }
        // Members move back to Uncategorized — drop their mappings.
        for (resultID, folderID) in membership where folderID == id {
            membership.removeValue(forKey: resultID)
        }
        persistFolders()
        persistMembership()
    }

    // MARK: - Membership

    /// Assigns the given result to a folder. Pass nil to make the item
    /// Uncategorized (or to remove it from its current folder).
    func assign(resultID: Int, to folderID: UUID?) {
        let key = String(resultID)
        if let folderID {
            membership[key] = folderID
        } else {
            membership.removeValue(forKey: key)
        }
        persistMembership()
    }

    func folderID(for resultID: Int) -> UUID? {
        membership[String(resultID)]
    }

    /// Drops the membership entry for a result. Called when a title leaves
    /// the watchlist entirely so it doesn't show up in a folder if the
    /// user re-saves it later.
    func forget(resultID: Int) {
        let key = String(resultID)
        guard membership[key] != nil else { return }
        membership.removeValue(forKey: key)
        persistMembership()
    }

    // MARK: - Persistence

    private func persistFolders() {
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: Self.foldersKey)
            CloudSync.pushIfSynced(Self.foldersKey)
        }
    }

    private func persistMembership() {
        if let encoded = try? JSONEncoder().encode(membership) {
            UserDefaults.standard.set(encoded, forKey: Self.membershipKey)
            CloudSync.pushIfSynced(Self.membershipKey)
        }
    }

    // MARK: - iCloud sync

    /// Re-read folders + membership from the (cloud-updated) store and
    /// republish, so a change synced from another device shows up live.
    private func reloadFromStore() {
        if let data = UserDefaults.standard.data(forKey: Self.foldersKey),
           let decoded = try? JSONDecoder().decode([Folder].self, from: data) {
            folders = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.membershipKey),
           let decoded = try? JSONDecoder().decode([String: UUID].self, from: data) {
            membership = decoded
        }
    }
}
