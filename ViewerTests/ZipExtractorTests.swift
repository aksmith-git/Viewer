import XCTest
@testable import Viewer

final class ZipExtractorTests: XCTestCase {
    var caches: URL!

    override func setUpWithError() throws {
        caches = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: caches) }

    func fixture(_ name: String) throws -> URL {
        let src = Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil)!
            .appendingPathComponent("zips/\(name)")
        let copy = caches.appendingPathComponent("in/\(name)")     // writable copy, like a picked file
        try FileManager.default.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: src, to: copy)
        return copy
    }

    func testExtractsNestedFiles() throws {
        let root = try ZipExtractor.extract(try fixture("nested.zip"), cachesRoot: caches)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("a/b/c.txt")), "deep")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("index.html").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("__MACOSX").path))
    }

    func testReusesExtraction() throws {
        let zip = try fixture("nested.zip")
        let first = try ZipExtractor.extract(zip, cachesRoot: caches)
        try Data("marker".utf8).write(to: first.appendingPathComponent("marker"))
        let second = try ZipExtractor.extract(zip, cachesRoot: caches)
        XCTAssertEqual(first, second)
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.appendingPathComponent("marker").path))
    }

    func testSingleTopFolderUnwrapped() throws {
        let root = try ZipExtractor.extract(try fixture("single-top.zip"), cachesRoot: caches)
        XCTAssertEqual(root.lastPathComponent, "site")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("css/x.css").path))
    }

    func testRejectsDotDotPath() throws {
        let zip = try fixture("evil.zip")
        XCTAssertThrowsError(try ZipExtractor.extract(zip, cachesRoot: caches)) { error in
            guard case ZipError.unsafePath(let p) = error else { return XCTFail("wrong error \(error)") }
            XCTAssertEqual(p, "../evil.txt")
        }
        let extracted = caches.appendingPathComponent("Extracted")
        XCTAssertFalse(FileManager.default.fileExists(atPath: caches.appendingPathComponent("evil.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: extracted.appendingPathComponent("evil.txt").path))
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: extracted.path)) ?? []
        XCTAssertTrue(leftovers.isEmpty, "partial extraction left behind: \(leftovers)")
    }
}
