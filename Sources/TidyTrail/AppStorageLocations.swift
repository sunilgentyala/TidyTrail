import Foundation
import TidyTrailCore

/// Single source of truth for where TidyTrail keeps its own on-device state
/// (deletion logs, the trash, and remembered folder bookmarks), so the Scan
/// and Trash tabs always agree on where to look.
enum AppStorageLocations {
    static let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    static let logsDirectory = documentsDirectory.appendingPathComponent("TidyTrail Logs", isDirectory: true)
    static let trashDirectory = documentsDirectory.appendingPathComponent("TidyTrail Trash", isDirectory: true)
    static let bookmarksFile = documentsDirectory.appendingPathComponent("TidyTrail Folders.json")

    static func makeTrashStore() -> TrashStore {
        TrashStore(trashDirectory: trashDirectory)
    }

    static func makeBookmarkStore() -> FolderBookmarkStore {
        FolderBookmarkStore(storageURL: bookmarksFile)
    }
}
