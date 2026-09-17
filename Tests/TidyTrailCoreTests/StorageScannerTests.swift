import XCTest
@testable import TidyTrailCore

final class StorageScannerTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testScanFindsFilesInNestedFolders() throws {
        let nested = tempDir.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        try Data("top".utf8).write(to: tempDir.appendingPathComponent("top.txt"))
        try Data("deep".utf8).write(to: nested.appendingPathComponent("deep.txt"))

        let items = try StorageScanner().scan(rootURL: tempDir)

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains { $0.name == "top.txt" && $0.size == 3 })
        XCTAssertTrue(items.contains { $0.name == "deep.txt" && $0.size == 4 })
    }

    func testScanIgnoresHiddenFiles() throws {
        try Data("visible".utf8).write(to: tempDir.appendingPathComponent("visible.txt"))
        try Data("hidden".utf8).write(to: tempDir.appendingPathComponent(".hidden.txt"))

        let items = try StorageScanner().scan(rootURL: tempDir)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "visible.txt")
    }

    func testPlainLocalFilesAreAlwaysMarkedDownloaded() throws {
        try Data("local".utf8).write(to: tempDir.appendingPathComponent("local.txt"))
        let items = try StorageScanner().scan(rootURL: tempDir)
        XCTAssertEqual(items.first?.isDownloaded, true)
    }

    func testProgressCallbackReportsARunningCount() throws {
        try Data("a".utf8).write(to: tempDir.appendingPathComponent("a.txt"))
        try Data("b".utf8).write(to: tempDir.appendingPathComponent("b.txt"))
        try Data("c".utf8).write(to: tempDir.appendingPathComponent("c.txt"))

        var progressValues: [Int] = []
        let items = try StorageScanner().scan(rootURL: tempDir, progress: { progressValues.append($0) })

        XCTAssertEqual(progressValues, Array(1...items.count))
    }

    func testScanThrowsCancellationErrorWhenCancelledFlagIsSet() throws {
        try Data("a".utf8).write(to: tempDir.appendingPathComponent("a.txt"))
        try Data("b".utf8).write(to: tempDir.appendingPathComponent("b.txt"))

        XCTAssertThrowsError(
            try StorageScanner().scan(rootURL: tempDir, isCancelled: { true })
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }
}
