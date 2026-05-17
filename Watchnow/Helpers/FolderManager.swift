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

    /// Curated SF Symbol set surfaced in the new-folder sheet's icon
    /// picker. Kept short to fit a single row of preset buttons.
    static let symbolPresets = [
        "folder",
        "film",
        "tv",
        "star.fill",
        "heart.fill",
        "sparkles",
        "bolt.fill",
        "crown.fill"
    ]
}

@MainActor
final class FolderManager: ObservableObject {

    static let shared = FolderManager()

    @Published private(set) var folders: [Folder]
    /// TMDB-id (as String) → folder-id. Items absent from the map are
    /// Uncategorized.
    @Published private(set) var membership: [String: UUID]

    private static let foldersKey = "watchlist_folders"
    private static let membershipKey = "watchlist_folder_membership"

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
        }
    }

    private func persistMembership() {
        if let encoded = try? JSONEncoder().encode(membership) {
            UserDefaults.standard.set(encoded, forKey: Self.membershipKey)
        }
    }
}
