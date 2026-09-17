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

    public init(id: UUID = UUID(), displayName: String, data: Data, createdDate: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.data = data
        self.createdDate = createdDate
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
        return FolderBookmark(displayName: url.lastPathComponent, data: data)
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

    /// Adds `bookmark` to the front of the list, replacing any existing
    /// bookmark with the same display name, and keeps at most `limit` entries.
    @discardableResult
    public func remember(_ bookmark: FolderBookmark, limit: Int = 10) throws -> [FolderBookmark] {
        var bookmarks = load().filter { $0.displayName != bookmark.displayName }
        bookmarks.insert(bookmark, at: 0)
        if bookmarks.count > limit {
            bookmarks = Array(bookmarks.prefix(limit))
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
