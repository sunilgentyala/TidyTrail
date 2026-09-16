import XCTest
@testable import TidyTrailCore

final class DuplicateFinderTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testFindsExactDuplicatesByContentNotJustSize() throws {
        let contentA = Data("hello tidytrail".utf8)
        let contentBSameSize = Data("totally-diff-16!".utf8) // same length as contentA, different bytes
        XCTAssertEqual(contentA.count, contentBSameSize.count)

        try contentA.write(to: tempDir.appendingPathComponent("one.txt"))
        try contentA.write(to: tempDir.appendingPathComponent("one-copy.txt"))
        try contentBSameSize.write(to: tempDir.appendingPathComponent("two.txt"))

        let items = try StorageScanner().scan(rootURL: tempDir)
        XCTAssertEqual(items.count, 3)

        let duplicates = try DuplicateFinder().findDuplicates(in: items)
        XCTAssertEqual(duplicates.count, 1)
        XCTAssertEqual(duplicates.first?.count, 2)
        XCTAssertTrue(duplicates.first?.allSatisfy { $0.name == "one.txt" || $0.name == "one-copy.txt" } ?? false)
    }

    func testIgnoresFilesWithNoDuplicates() throws {
        try Data("unique".utf8).write(to: tempDir.appendingPathComponent("solo.txt"))
        let items = try StorageScanner().scan(rootURL: tempDir)
        let duplicates = try DuplicateFinder().findDuplicates(in: items)
        XCTAssertTrue(duplicates.isEmpty)
    }

    func testIgnoresZeroByteFiles() throws {
        try Data().write(to: tempDir.appendingPathComponent("empty1.txt"))
        try Data().write(to: tempDir.appendingPathComponent("empty2.txt"))
        let items = try StorageScanner().scan(rootURL: tempDir)
        let duplicates = try DuplicateFinder().findDuplicates(in: items)
        XCTAssertTrue(duplicates.isEmpty)
    }
}
