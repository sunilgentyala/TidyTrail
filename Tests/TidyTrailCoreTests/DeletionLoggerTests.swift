import XCTest
@testable import TidyTrailCore

final class DeletionLoggerTests: XCTestCase {
    var tempDir: URL!
    var logsDir: URL!
    var trashDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        logsDir = tempDir.appendingPathComponent("Logs", isDirectory: true)
        trashDir = tempDir.appendingPathComponent("Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testTrashesFileAndWritesLogReflectingSuccess() throws {
        let fileURL = tempDir.appendingPathComponent("to-delete.txt")
        try Data("delete me".utf8).write(to: fileURL)

        let item = FileItem(url: fileURL, name: "to-delete.txt", size: 9, modificationDate: Date())
        let trashStore = TrashStore(trashDirectory: trashDir)
        let logger = DeletionLogger(logsDirectory: logsDir, trashStore: trashStore)

        let (logURL, records) = try logger.trashWithLog(items: [item], folderBookmarkID: nil)

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "source file should be moved out of its original folder")
        XCTAssertTrue(FileManager.default.fileExists(atPath: logURL.path), "log file should exist")
        XCTAssertEqual(trashStore.loadManifest().count, 1, "the trash manifest should record the moved item")

        let logContents = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(logContents.contains("TRASHED"))
        XCTAssertTrue(logContents.contains("to-delete.txt"))

        guard case .trashed = records.first?.outcome else {
            return XCTFail("expected .trashed outcome")
        }
    }

    func testRecordsFailureWhenFileIsMissing() throws {
        let missingURL = tempDir.appendingPathComponent("missing.txt")
        let item = FileItem(url: missingURL, name: "missing.txt", size: 0, modificationDate: Date())
        let trashStore = TrashStore(trashDirectory: trashDir)
        let logger = DeletionLogger(logsDirectory: logsDir, trashStore: trashStore)

        let (logURL, records) = try logger.trashWithLog(items: [item], folderBookmarkID: nil)

        guard case .failed = records.first?.outcome else {
            return XCTFail("expected .failed outcome for a file that no longer exists")
        }

        let logContents = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(logContents.contains("FAILED"))
    }

    func testLogManifestExistsWithPendingStatusBeforeTrashingRuns() throws {
        let fileURL = tempDir.appendingPathComponent("ordering.txt")
        try Data("x".utf8).write(to: fileURL)
        let item = FileItem(url: fileURL, name: "ordering.txt", size: 1, modificationDate: Date())

        let spy = MoveItemSpyFileManager(logsDir: logsDir)
        let trashStore = TrashStore(trashDirectory: trashDir, fileManager: spy)
        let logger = DeletionLogger(logsDirectory: logsDir, trashStore: trashStore)
        _ = try logger.trashWithLog(items: [item], folderBookmarkID: nil)

        XCTAssertTrue(spy.logContentsAtFirstMoveCall?.contains("PENDING") ?? false)
        XCTAssertTrue(spy.logContentsAtFirstMoveCall?.contains("ordering.txt") ?? false)
    }
}

/// Captures the on-disk log contents at the moment the first `moveItem`
/// call happens, to prove the manifest is written before anything is moved.
private final class MoveItemSpyFileManager: FileManager {
    let logsDir: URL
    var logContentsAtFirstMoveCall: String?

    init(logsDir: URL) {
        self.logsDir = logsDir
        super.init()
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if logContentsAtFirstMoveCall == nil {
            let logFile = try? FileManager.default.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: nil).first
            if let logFile {
                logContentsAtFirstMoveCall = try? String(contentsOf: logFile, encoding: .utf8)
            }
        }
        try FileManager.default.moveItem(at: srcURL, to: dstURL)
    }
}
