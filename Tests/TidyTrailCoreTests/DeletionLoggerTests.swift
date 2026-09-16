import XCTest
@testable import TidyTrailCore

final class DeletionLoggerTests: XCTestCase {
    var tempDir: URL!
    var logsDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        logsDir = tempDir.appendingPathComponent("Logs", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testDeletesFileAndWritesLogReflectingSuccess() throws {
        let fileURL = tempDir.appendingPathComponent("to-delete.txt")
        try Data("delete me".utf8).write(to: fileURL)

        let item = FileItem(url: fileURL, name: "to-delete.txt", size: 9, modificationDate: Date())
        let logger = DeletionLogger(logsDirectory: logsDir)

        let (logURL, records) = try logger.deleteWithLog(items: [item])

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "source file should be deleted")
        XCTAssertTrue(FileManager.default.fileExists(atPath: logURL.path), "log file should exist")

        let logContents = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(logContents.contains("DELETED"))
        XCTAssertTrue(logContents.contains("to-delete.txt"))

        guard case .deleted = records.first?.outcome else {
            return XCTFail("expected .deleted outcome")
        }
    }

    func testRecordsFailureWhenFileIsMissing() throws {
        let missingURL = tempDir.appendingPathComponent("missing.txt")
        let item = FileItem(url: missingURL, name: "missing.txt", size: 0, modificationDate: Date())
        let logger = DeletionLogger(logsDirectory: logsDir)

        let (logURL, records) = try logger.deleteWithLog(items: [item])

        guard case .failed = records.first?.outcome else {
            return XCTFail("expected .failed outcome for a file that no longer exists")
        }

        let logContents = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(logContents.contains("FAILED"))
    }

    func testLogManifestExistsWithPendingStatusBeforeDeletionRuns() throws {
        let fileURL = tempDir.appendingPathComponent("ordering.txt")
        try Data("x".utf8).write(to: fileURL)
        let item = FileItem(url: fileURL, name: "ordering.txt", size: 1, modificationDate: Date())

        let spy = RemoveItemSpyFileManager(logsDir: logsDir)
        let logger = DeletionLogger(logsDirectory: logsDir, fileManager: spy)
        _ = try logger.deleteWithLog(items: [item])

        XCTAssertTrue(spy.logContentsAtFirstRemoveCall?.contains("PENDING") ?? false)
        XCTAssertTrue(spy.logContentsAtFirstRemoveCall?.contains("ordering.txt") ?? false)
    }
}

/// Captures the on-disk log contents at the moment the first `removeItem`
/// call happens, to prove the manifest is written before any deletion.
private final class RemoveItemSpyFileManager: FileManager {
    let logsDir: URL
    var logContentsAtFirstRemoveCall: String?

    init(logsDir: URL) {
        self.logsDir = logsDir
        super.init()
    }

    override func removeItem(at URL: URL) throws {
        if logContentsAtFirstRemoveCall == nil {
            let logFile = try? FileManager.default.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: nil).first
            if let logFile {
                logContentsAtFirstRemoveCall = try? String(contentsOf: logFile, encoding: .utf8)
            }
        }
        try FileManager.default.removeItem(at: URL)
    }
}
