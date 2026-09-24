import XCTest
@testable import TidyTrailCore

final class TrashStoreTests: XCTestCase {
    var tempDir: URL!
    var originalDir: URL!
    var trashDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        originalDir = tempDir.appendingPathComponent("Original", isDirectory: true)
        trashDir = tempDir.appendingPathComponent("Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: originalDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeFile(named name: String, in directory: URL, contents: String = "hello") throws -> FileItem {
        let url = directory.appendingPathComponent(name)
        let data = Data(contents.utf8)
        try data.write(to: url)
        return FileItem(url: url, name: name, size: Int64(data.count), modificationDate: Date())
    }

    func testMoveToTrashMovesFileAndRecordsManifest() throws {
        let item = try makeFile(named: "a.txt", in: originalDir)
        let store = TrashStore(trashDirectory: trashDir)

        let trashed = try store.moveToTrash(item: item, folderBookmarkID: nil)

        XCTAssertFalse(FileManager.default.fileExists(atPath: item.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: trashDir.appendingPathComponent(trashed.trashedFileName).path))
        XCTAssertEqual(store.loadManifest().map(\.id), [trashed.id])
    }

    func testRestoreMovesFileBackAndRemovesFromManifest() throws {
        let item = try makeFile(named: "b.txt", in: originalDir)
        let store = TrashStore(trashDirectory: trashDir)
        let trashed = try store.moveToTrash(item: item, folderBookmarkID: nil)

        let restoredURL = try store.restore(trashed, to: originalDir)

        XCTAssertEqual(restoredURL, originalDir.appendingPathComponent("b.txt"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoredURL.path))
        XCTAssertTrue(store.loadManifest().isEmpty)
    }

    func testRestoreRenamesRatherThanOverwritingAnExistingFile() throws {
        let item = try makeFile(named: "c.txt", in: originalDir, contents: "original")
        let store = TrashStore(trashDirectory: trashDir)
        let trashed = try store.moveToTrash(item: item, folderBookmarkID: nil)

        // Something new now occupies the original name.
        try Data("someone else's file".utf8).write(to: originalDir.appendingPathComponent("c.txt"))

        let restoredURL = try store.restore(trashed, to: originalDir)

        XCTAssertEqual(restoredURL.lastPathComponent, "c (1).txt")
        XCTAssertEqual(try String(contentsOf: originalDir.appendingPathComponent("c.txt"), encoding: .utf8), "someone else's file")
        XCTAssertEqual(try String(contentsOf: restoredURL, encoding: .utf8), "original")
    }

    func testDeleteForeverRemovesFileAndManifestEntry() throws {
        let item = try makeFile(named: "d.txt", in: originalDir)
        let store = TrashStore(trashDirectory: trashDir)
        let trashed = try store.moveToTrash(item: item, folderBookmarkID: nil)

        try store.deleteForever(trashed)

        XCTAssertFalse(FileManager.default.fileExists(atPath: trashDir.appendingPathComponent(trashed.trashedFileName).path))
        XCTAssertTrue(store.loadManifest().isEmpty)
    }

    func testPurgeExpiredRemovesOnlyItemsPastRetention() throws {
        let oldItem = try makeFile(named: "old.txt", in: originalDir)
        let newItem = try makeFile(named: "new.txt", in: originalDir)

        var now = Date()
        let store = TrashStore(trashDirectory: trashDir, dateProvider: { now }, retentionInterval: 30 * 86400)

        let trashedOld = try store.moveToTrash(item: oldItem, folderBookmarkID: nil)
        now = now.addingTimeInterval(31 * 86400) // "trash" the second item 31 days later
        let trashedNew = try store.moveToTrash(item: newItem, folderBookmarkID: nil)

        let purged = try store.purgeExpired()

        XCTAssertEqual(purged.map(\.id), [trashedOld.id])
        let remaining = store.loadManifest()
        XCTAssertEqual(remaining.map(\.id), [trashedNew.id])
        XCTAssertFalse(FileManager.default.fileExists(atPath: trashDir.appendingPathComponent(trashedOld.trashedFileName).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: trashDir.appendingPathComponent(trashedNew.trashedFileName).path))
    }

    /// Writes a manifest by hand, the way someone editing the file-shared
    /// Documents folder (or a sync/backup tool) could.
    private func writeTamperedManifest(_ items: [TrashedItem]) throws {
        try FileManager.default.createDirectory(at: trashDir, withIntermediateDirectories: true)
        try JSONEncoder().encode(items).write(to: trashDir.appendingPathComponent("manifest.json"))
    }

    func testTamperedManifestCannotDeleteFilesOutsideTheTrash() throws {
        let victim = try makeFile(named: "victim.txt", in: tempDir)
        let evil = TrashedItem(
            originalURL: victim.url,
            trashedFileName: "../victim.txt",
            name: "victim.txt",
            size: 1,
            trashedDate: .distantPast,
            folderBookmarkID: nil
        )
        try writeTamperedManifest([evil])
        let store = TrashStore(trashDirectory: trashDir)

        XCTAssertTrue(store.loadManifest().isEmpty, "unsafe entries must be dropped on load")
        _ = try store.purgeExpired()
        XCTAssertThrowsError(try store.deleteForever(evil))
        XCTAssertTrue(FileManager.default.fileExists(atPath: victim.url.path))
    }

    func testTamperedManifestCannotRestoreOutsideTheDestinationFolder() throws {
        let item = try makeFile(named: "e.txt", in: originalDir)
        let store = TrashStore(trashDirectory: trashDir)
        let trashed = try store.moveToTrash(item: item, folderBookmarkID: nil)

        let evil = TrashedItem(
            id: trashed.id,
            originalURL: trashed.originalURL,
            trashedFileName: trashed.trashedFileName,
            name: "../escaped.txt",
            size: trashed.size,
            trashedDate: trashed.trashedDate,
            folderBookmarkID: nil
        )
        try writeTamperedManifest([evil])

        XCTAssertTrue(store.loadManifest().isEmpty)
        XCTAssertThrowsError(try store.restore(evil, to: originalDir))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("escaped.txt").path))
    }

    func testVeryLongFileNamesCanStillBeTrashed() throws {
        let longName = String(repeating: "a", count: 250) + ".txt"
        let item = try makeFile(named: longName, in: originalDir)
        let store = TrashStore(trashDirectory: trashDir)

        let trashed = try store.moveToTrash(item: item, folderBookmarkID: nil)

        XCTAssertLessThanOrEqual(trashed.trashedFileName.utf8.count, 255)
        XCTAssertEqual(trashed.name, longName)
        let restored = try store.restore(trashed, to: originalDir)
        XCTAssertEqual(restored.lastPathComponent, longName)
    }

    func testSafeFileNameRules() {
        XCTAssertTrue(TrashStore.isSafeFileName("report: final.txt"))
        XCTAssertFalse(TrashStore.isSafeFileName(""))
        XCTAssertFalse(TrashStore.isSafeFileName("."))
        XCTAssertFalse(TrashStore.isSafeFileName(".."))
        XCTAssertFalse(TrashStore.isSafeFileName("a/b"))
        XCTAssertFalse(TrashStore.isSafeFileName("../x"))
    }

    func testExpirationDateIsTrashedDatePlusRetention() {
        let trashedDate = Date()
        let store = TrashStore(trashDirectory: trashDir, retentionInterval: 30 * 86400)
        let item = TrashedItem(
            originalURL: originalDir.appendingPathComponent("x.txt"),
            trashedFileName: "x.txt",
            name: "x.txt",
            size: 1,
            trashedDate: trashedDate,
            folderBookmarkID: nil
        )

        XCTAssertEqual(store.expirationDate(for: item), trashedDate.addingTimeInterval(30 * 86400))
    }
}
