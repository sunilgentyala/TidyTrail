import Foundation
import TidyTrailCore

/// Single source of truth for where TidyTrail keeps its own on-device state
/// (deletion logs, the trash, and remembered folder bookmarks), so the Scan
/// and Trash screens always agree on where to look.
///
/// On iOS this is the app's Documents directory, which is intentionally
/// file-shared (`UIFileSharingEnabled`) so a user can browse it in Files.
/// On macOS, Documents is the user's real `~/Documents`, which isn't a place
/// a background utility app should be dropping its own housekeeping files -
/// so the Mac app keeps the same layout under Application Support instead.
enum AppStorageLocations {
    static let baseDirectory: URL = {
        #if os(macOS)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("TidyTrail", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #endif
    }()

    static let logsDirectory = baseDirectory.appendingPathComponent("TidyTrail Logs", isDirectory: true)
    static let trashDirectory = baseDirectory.appendingPathComponent("TidyTrail Trash", isDirectory: true)
    static let bookmarksFile = baseDirectory.appendingPathComponent("TidyTrail Folders.json")

    static func makeTrashStore() -> TrashStore {
        TrashStore(trashDirectory: trashDirectory)
    }

    static func makeBookmarkStore() -> FolderBookmarkStore {
        FolderBookmarkStore(storageURL: bookmarksFile)
    }
}
