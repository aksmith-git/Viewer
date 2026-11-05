import XCTest
@testable import Viewer

final class TextLoaderTests: XCTestCase {
    func write(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testUTF8() throws {
        let r = try TextLoader.load(try write(Data("héllo wörld ✓".utf8)), limit: 1000)
        XCTAssertEqual(r.text, "héllo wörld ✓")
        XCTAssertFalse(r.truncated)
    }

    func testUTF16BOM() throws {
        let r = try TextLoader.load(try write("ünïcode".data(using: .utf16)!), limit: 1000)   // .utf16 adds a BOM
        XCTAssertEqual(r.text, "ünïcode")
    }

    func testLatin1Fallback() throws {
        let r = try TextLoader.load(try write(Data([0x63, 0x61, 0x66, 0xE9])), limit: 1000)   // "café" in Latin-1
        XCTAssertEqual(r.text, "café")
    }

    func testTextTruncatedOver5MB() throws {
        let line = String(repeating: "abcdefghij", count: 10) + "\n"
        let big = String(repeating: line, count: 6 * 1024 * 1024 / line.utf8.count + 1)
        let r = try TextLoader.load(try write(Data(big.utf8)), limit: 5 * 1024 * 1024)
        XCTAssertTrue(r.truncated)
        XCTAssertLessThanOrEqual(r.text.utf8.count, 5 * 1024 * 1024)
        XCTAssertGreaterThan(r.text.utf8.count, 5 * 1024 * 1024 - 8)
    }

    func testNoSplitMultibyte() throws {
        let data = Data("ab✓cd".utf8)          // ✓ is 3 bytes at offsets 2..4
        let r = try TextLoader.load(try write(data), limit: 3)
        XCTAssertEqual(r.text, "ab")
        XCTAssertTrue(r.truncated)
    }
}
