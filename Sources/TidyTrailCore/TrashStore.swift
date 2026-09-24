import Foundation

/// A file TidyTrail has removed from its original folder but kept in its own
/// sandbox so it can be restored, mirroring the "Recently Deleted" pattern
/// from Photos and Files instead of deleting on the spot.
public struct TrashedItem: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public let originalURL: URL
    /// File name inside the trash directory - a UUID prefix keeps two
    /// trashed files that originally shared a name from colliding.
    public let trashedFileName: String
    public let name: String
    public let size: Int64
    public let trashedDate: Date
    /// The bookmark for the folder this item came from, if any, so it can be
    /// restored to that exact folder later. Nil means restore isn't possible
    /// (e.g. the folder wasn't bookmarked) and only "Delete Forever" applies.
    public let folderBookmarkID: UUID?

    public init(
        id: UUID = UUID(),
        originalURL: URL,
        trashedFileName: String,
        name: String,
        size: Int64,
        trashedDate: Date,
        folderBookmarkID: UUID?
    ) {
        self.id = id
        self.originalURL = originalURL
        self.trashedFileName = trashedFileName
        self.name = name
        self.size = size
        self.trashedDate = trashedDate
        self.folderBookmarkID = folderBookmarkID
    }
}

/// Moves files the user chose to delete into an app-owned trash folder
/// instead of deleting them immediately, and keeps a JSON manifest of what's
/// in there. Files sit in the trash for `retentionInterval` (30 days, matching
/// the Photos app's Recently Deleted) before `purgeExpired()` removes them
/// for good.
public struct TrashStore: @unchecked Sendable {
    public static let defaultRetentionInterval: TimeInterval = 30 * 24 * 60 * 60

    private let trashDirectory: URL
    private let manifestURL: URL
    private let fileManager: FileManager
    private let dateProvider: () -> Date
    public let retentionInterval: TimeInterval

    public init(
        trashDirectory: URL,
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = Date.init,
        retentionInterval: TimeInterval = TrashStore.defaultRetentionInterval
    ) {
        self.trashDirectory = trashDirectory
        self.manifestURL = trashDirectory.appendingPathComponent("manifest.json")
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.retentionInterval = retentionInterval
    }

    @discardableResult
    public func ensureTrashDirectoryExists() throws -> URL {
        if !fileManager.fileExists(atPath: trashDirectory.path) {
            try fileManager.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        }
        return trashDirectory
    }

    public enum TrashError: Error, LocalizedError, Equatable {
        case unsafeFileName(String)

        public var errorDescription: String? {
            switch self {
            case .unsafeFileName(let name):
                return "\"\(name)\" is not a safe file name, so TidyTrail refused to use it."
            }
        }
    }

    /// Returns the trash contents, dropping any manifest entry whose file is
    /// no longer actually in the trash directory. TidyTrail's own Documents
    /// folder is file-shared (`UIFileSharingEnabled`), so a user browsing
    /// there in the Files app could move or delete a trashed file directly -
    /// the manifest should never claim a file is recoverable when it isn't.
    ///
    /// For the same reason the manifest itself is untrusted input: anyone
    /// with access to that folder (or a sync tool, or a backup restore) can
    /// edit it. Entries whose file names aren't a single plain path
    /// component (e.g. `../../Library/...`) are dropped here, so a tampered
    /// manifest can never steer `deleteForever`/`purgeExpired` at a file
    /// outside the trash directory or `restore` outside the chosen folder.
    public func loadManifest() -> [TrashedItem] {
        guard let data = try? Data(contentsOf: manifestURL) else { return [] }
        let items = (try? JSONDecoder().decode([TrashedItem].self, from: data)) ?? []
        return items.filter {
            Self.isSafeFileName($0.trashedFileName)
                && Self.isSafeFileName($0.name)
                && fileManager.fileExists(atPath: trashDirectory.appendingPathComponent($0.trashedFileName).path)
        }
    }

    /// True only for a single path component: non-empty, not `.` or `..`,
    /// no `/` separator and no NUL. Everything else (including `:` and
    /// control characters) is a legal APFS file name, so rejecting it would
    /// just make real files impossible to trash.
    static func isSafeFileName(_ name: String) -> Bool {
        guard !name.isEmpty, name != ".", name != "..", name.utf8.count <= 255 else { return false }
        return !name.contains("/") && !name.contains("\0")
    }

    /// The file inside the trash directory for `item`, refusing any name
    /// that could resolve outside it.
    private func trashFileURL(for item: TrashedItem) throws -> URL {
        guard Self.isSafeFileName(item.trashedFileName) else {
            throw TrashError.unsafeFileName(item.trashedFileName)
        }
        return trashDirectory.appendingPathComponent(item.trashedFileName)
    }

    /// `UUID-` prefix plus the original name, trimmed so the result stays
    /// within the 255-byte file-name limit (otherwise a long original name
    /// would make the move into the trash fail outright).
    static func makeTrashedFileName(for name: String) -> String {
        let prefix = UUID().uuidString + "-"
        var trimmed = name
        while (prefix + trimmed).utf8.count > 255, !trimmed.isEmpty {
            trimmed.removeFirst()
        }
        return prefix + trimmed
    }

    /// The date `item` will be permanently purged if it isn't restored first.
    public func expirationDate(for item: TrashedItem) -> Date {
        item.trashedDate.addingTimeInterval(retentionInterval)
    }

    /// Moves `item` into the trash directory and records it in the manifest.
    /// Throws (and records nothing) if the move itself fails, so a failed
    /// trash never shows up as if it succeeded.
    @discardableResult
    public func moveToTrash(item: FileItem, folderBookmarkID: UUID?) throws -> TrashedItem {
        try ensureTrashDirectoryExists()
        guard Self.isSafeFileName(item.name) else {
            throw TrashError.unsafeFileName(item.name)
        }
        let trashedFileName = Self.makeTrashedFileName(for: item.name)
        let destination = trashDirectory.appendingPathComponent(trashedFileName)

        try fileManager.moveItem(at: item.url, to: destination)

        let trashedItem = TrashedItem(
            originalURL: item.url,
            trashedFileName: trashedFileName,
            name: item.name,
            size: item.size,
            trashedDate: dateProvider(),
            folderBookmarkID: folderBookmarkID
        )
        var items = loadManifest()
        items.append(trashedItem)
        try saveManifest(items)
        return trashedItem
    }

    /// Moves a trashed item back into `destinationFolder` (its original
    /// folder, reopened via a resolved bookmark) and removes it from the
    /// manifest. If a file with the same name already exists there, the
    /// restored copy is renamed rather than overwriting it.
    @discardableResult
    public func restore(_ trashedItem: TrashedItem, to destinationFolder: URL) throws -> URL {
        let source = try trashFileURL(for: trashedItem)
        guard Self.isSafeFileName(trashedItem.name) else {
            throw TrashError.unsafeFileName(trashedItem.name)
        }
        let destination = Self.uniqueDestination(
            for: destinationFolder.appendingPathComponent(trashedItem.name),
            fileManager: fileManager
        )

        try fileManager.moveItem(at: source, to: destination)
        try removeFromManifest(trashedItem.id)
        return destination
    }

    /// Permanently deletes a trashed item's file and removes it from the manifest.
    public func deleteForever(_ trashedItem: TrashedItem) throws {
        let fileURL = try trashFileURL(for: trashedItem)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        try removeFromManifest(trashedItem.id)
    }

    /// Permanently deletes every trashed item older than `retentionInterval`
    /// and returns what was purged, so the caller can log it.
    @discardableResult
    public func purgeExpired() throws -> [TrashedItem] {
        let now = dateProvider()
        let expired = loadManifest().filter { now.timeIntervalSince($0.trashedDate) >= retentionInterval }
        for item in expired {
            try? deleteForever(item)
        }
        return expired
    }

    private func saveManifest(_ items: [TrashedItem]) throws {
        let data = try JSONEncoder().encode(items)
        try data.write(to: manifestURL, options: .atomic)
    }

    private func removeFromManifest(_ id: UUID) throws {
        let items = loadManifest().filter { $0.id != id }
        try saveManifest(items)
    }

    private static func uniqueDestination(for url: URL, fileManager: FileManager) -> URL {
        guard fileManager.fileExists(atPath: url.path) else { return url }
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        let folder = url.deletingLastPathComponent()
        var counter = 1
        var candidate = url
        while fileManager.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            candidate = folder.appendingPathComponent(name)
            counter += 1
        }
        return candidate
    }
}
