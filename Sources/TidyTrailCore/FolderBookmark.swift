import Foundation

/// Persists a bookmark to a user-picked folder so TidyTrail can reopen it
/// later - for a one-tap rescan, and so a trashed item can be restored to its
/// original folder even after the picker session that trashed it has ended.
///
/// Without this, the app drops access to a folder as soon as the picker
/// session that granted it ends, and every rescan or restore would need the
/// user to pick it again. `.withSecurityScope` is macOS-only (it's how a
/// sandboxed Mac app's Powerbox-granted `NSOpenPanel` selection survives a
/// relaunch); on iOS, a plain bookmark plus
/// `startAccessingSecurityScopedResource()` on the resolved URL is Apple's
/// documented pattern for a `UIDocumentPickerViewController` grant instead.
public struct FolderBookmark: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public let displayName: String
    public let data: Data
    public let createdDate: Date
    /// The folder's standardized path when the bookmark was made. Used only
    /// to recognize "this is the same folder again", never to open it (that
    /// always goes through `data`). Optional so bookmarks saved by earlier
    /// versions, which didn't record it, still decode.
    public let path: String?

    public init(id: UUID = UUID(), displayName: String, data: Data, createdDate: Date = Date(), path: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.data = data
        self.createdDate = createdDate
        self.path = path
    }

    /// Creates a bookmark for `url`, which must already be accessible -
    /// typically the URL just handed over by `UIDocumentPickerViewController`
    /// (iOS) or `NSOpenPanel` (macOS).
    public static func make(for url: URL) throws -> FolderBookmark {
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkCreationOptions = []
        #endif
        let data = try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
        return FolderBookmark(displayName: url.lastPathComponent, data: data, path: url.standardizedFileURL.path)
    }

    /// Two bookmarks refer to the same folder if their recorded paths match,
    /// or - for older bookmarks with no recorded path - their names match.
    func refersToSameFolder(as other: FolderBookmark) -> Bool {
        if let path, let otherPath = other.path {
            return path == otherPath
        }
        return displayName == other.displayName
    }

    /// A copy of this bookmark carrying `id` instead of its own.
    func withID(_ id: UUID) -> FolderBookmark {
        FolderBookmark(id: id, displayName: displayName, data: data, createdDate: createdDate, path: path)
    }

    /// Resolves the bookmark back to a URL and starts security-scoped access.
    /// The caller must call `stopAccessingSecurityScopedResource()` on the
    /// returned URL when done, but only if `didStartAccessing` is true.
    public func resolve() throws -> (url: URL, didStartAccessing: Bool) {
        var isStale = false
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        let url = try URL(resolvingBookmarkData: data, options: options, relativeTo: nil, bookmarkDataIsStale: &isStale)
        let didStart = url.startAccessingSecurityScopedResource()
        return (url, didStart)
    }
}

/// Reads and writes the list of remembered folder bookmarks as JSON, newest first.
public struct FolderBookmarkStore: Sendable {
    private let fileURL: URL

    public init(storageURL: URL) {
        self.fileURL = storageURL
    }

    public func load() -> [FolderBookmark] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([FolderBookmark].self, from: data)) ?? []
    }

    /// Adds `bookmark` to the front of the list and keeps at most `limit`
    /// entries. Returns the updated list; its first element is the bookmark
    /// as stored, which callers must use for its `id`.
    ///
    /// If the same folder was already remembered, the existing entry's `id`
    /// is kept (with the fresh bookmark data), because trashed items point
    /// at that id to know where to restore to. Minting a new id on every
    /// re-pick used to orphan those items and break their restore.
    ///
    /// Bookmarks whose ids are in `keeping` (e.g. ones still referenced by
    /// items in the trash) are never dropped by the `limit`, for the same
    /// reason.
    @discardableResult
    public func remember(_ bookmark: FolderBookmark, limit: Int = 10, keeping: Set<UUID> = []) throws -> [FolderBookmark] {
        var bookmarks = load()
        var stored = bookmark
        if let existing = bookmarks.first(where: { $0.refersToSameFolder(as: bookmark) }) {
            stored = bookmark.withID(existing.id)
        }
        bookmarks.removeAll { $0.id == stored.id || $0.refersToSameFolder(as: stored) }
        bookmarks.insert(stored, at: 0)

        if bookmarks.count > limit {
            var kept: [FolderBookmark] = []
            for (index, entry) in bookmarks.enumerated() where index < limit || keeping.contains(entry.id) {
                kept.append(entry)
            }
            bookmarks = kept
        }
        try save(bookmarks)
        return bookmarks
    }

    @discardableResult
    public func forget(id: UUID) throws -> [FolderBookmark] {
        let bookmarks = load().filter { $0.id != id }
        try save(bookmarks)
        return bookmarks
    }

    private func save(_ bookmarks: [FolderBookmark]) throws {
        let data = try JSONEncoder().encode(bookmarks)
        try data.write(to: fileURL, options: .atomic)
    }
}
