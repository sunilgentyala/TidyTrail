import XCTest
@testable import TidyTrailCore

final class ByteFormatterTests: XCTestCase {
    func testFormatsNonZeroBytesWithADigit() {
        let result = ByteFormatter.string(fromBytes: 1_048_576)
        XCTAssertFalse(result.isEmpty)
        XCTAssertNotNil(result.rangeOfCharacter(from: .decimalDigits))
    }

    func testFormatsZeroBytes() {
        let result = ByteFormatter.string(fromBytes: 0)
        XCTAssertFalse(result.isEmpty)
    }
}
