import XCTest
@testable import TidyTrailCore

final class FolderBookmarkTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testMakeAndResolveRoundTripsToTheSamePath() throws {
        let folder = tempDir.appendingPathComponent("Picked", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let bookmark = try FolderBookmark.make(for: folder)
        let (resolvedURL, didStartAccessing) = try bookmark.resolve()
        defer { if didStartAccessing { resolvedURL.stopAccessingSecurityScopedResource() } }

        XCTAssertEqual(resolvedURL.standardizedFileURL.path, folder.standardizedFileURL.path)
        XCTAssertEqual(bookmark.displayName, "Picked")
    }

    func testStoreRoundTripsRememberedBookmarks() throws {
        let storeURL = tempDir.appendingPathComponent("bookmarks.json")
        let store = FolderBookmarkStore(storageURL: storeURL)
        XCTAssertTrue(store.load().isEmpty)

        let bookmark = FolderBookmark(displayName: "Downloads", data: Data("fake".utf8))
        try store.remember(bookmark)

        XCTAssertEqual(store.load().map(\.displayName), ["Downloads"])
    }

    func testRememberingSameDisplayNameReplacesTheOlderEntryAndMovesItToTheFront() throws {
        let storeURL = tempDir.appendingPathComponent("bookmarks.json")
        let store = FolderBookmarkStore(storageURL: storeURL)

        try store.remember(FolderBookmark(displayName: "Downloads", data: Data("v1".utf8)))
        try store.remember(FolderBookmark(displayName: "Documents", data: Data("v1".utf8)))
        try store.remember(FolderBookmark(displayName: "Downloads", data: Data("v2".utf8)))

        let loaded = store.load()
        XCTAssertEqual(loaded.map(\.displayName), ["Downloads", "Documents"])
        XCTAssertEqual(loaded.first?.data, Data("v2".utf8))
    }

    func testRememberEnforcesLimit() throws {
        let storeURL = tempDir.appendingPathComponent("bookmarks.json")
        let store = FolderBookmarkStore(storageURL: storeURL)

        for index in 0..<5 {
            try store.remember(FolderBookmark(displayName: "Folder\(index)", data: Data()), limit: 3)
        }

        XCTAssertEqual(store.load().count, 3)
        XCTAssertEqual(store.load().first?.displayName, "Folder4")
    }

    func testForgetRemovesOnlyTheMatchingBookmark() throws {
        let storeURL = tempDir.appendingPathComponent("bookmarks.json")
        let store = FolderBookmarkStore(storageURL: storeURL)

        let keep = FolderBookmark(displayName: "Keep", data: Data())
        let remove = FolderBookmark(displayName: "Remove", data: Data())
        try store.remember(keep)
        try store.remember(remove)

        try store.forget(id: remove.id)

        XCTAssertEqual(store.load().map(\.id), [keep.id])
    }
}
