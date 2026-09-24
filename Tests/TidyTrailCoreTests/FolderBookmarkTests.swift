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

    /// Trashed items remember the id of the folder they came from; picking
    /// that folder again must not change its id or their restore breaks.
    func testRePickingTheSameFolderKeepsItsOriginalID() throws {
        let store = FolderBookmarkStore(storageURL: tempDir.appendingPathComponent("bookmarks.json"))
        let first = FolderBookmark(displayName: "Downloads", data: Data("v1".utf8), path: "/a/Downloads")
        try store.remember(first)

        let again = FolderBookmark(displayName: "Downloads", data: Data("v2".utf8), path: "/a/Downloads")
        let stored = try store.remember(again)

        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.id, first.id)
        XCTAssertEqual(stored.first?.data, Data("v2".utf8))
    }

    func testDifferentFoldersWithTheSameNameAreBothRemembered() throws {
        let store = FolderBookmarkStore(storageURL: tempDir.appendingPathComponent("bookmarks.json"))
        let iCloud = FolderBookmark(displayName: "Downloads", data: Data(), path: "/iCloud/Downloads")
        let local = FolderBookmark(displayName: "Downloads", data: Data(), path: "/OnMyiPhone/Downloads")
        try store.remember(iCloud)
        try store.remember(local)

        XCTAssertEqual(Set(store.load().map(\.id)), [iCloud.id, local.id])
    }

    func testLimitNeverDropsABookmarkTheTrashStillNeeds() throws {
        let store = FolderBookmarkStore(storageURL: tempDir.appendingPathComponent("bookmarks.json"))
        let needed = FolderBookmark(displayName: "Needed", data: Data(), path: "/needed")
        try store.remember(needed, limit: 2)
        for index in 0..<3 {
            try store.remember(
                FolderBookmark(displayName: "F\(index)", data: Data(), path: "/f\(index)"),
                limit: 2,
                keeping: [needed.id]
            )
        }

        XCTAssertTrue(store.load().contains { $0.id == needed.id })
    }

    func testBookmarksSavedWithoutAPathStillDecode() throws {
        let storeURL = tempDir.appendingPathComponent("bookmarks.json")
        let legacy = #"[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","displayName":"Old","data":"","createdDate":0}]"#
        try Data(legacy.utf8).write(to: storeURL)

        let loaded = FolderBookmarkStore(storageURL: storeURL).load()
        XCTAssertEqual(loaded.map(\.displayName), ["Old"])
        XCTAssertNil(loaded.first?.path)
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
