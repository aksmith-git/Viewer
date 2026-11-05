import XCTest
@testable import Viewer

final class FileKindTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    @discardableResult
    func file(_ name: String, _ text: String = "hello") throws -> URL {
        try file(name, data: Data(text.utf8))
    }

    @discardableResult
    func file(_ name: String, data: Data) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }

    func testHTMLByExtension() throws { XCTAssertEqual(FileKind.classify(try file("a.htm", "<p>x")), .html) }
    func testUppercaseExtension() throws { XCTAssertEqual(FileKind.classify(try file("A.HTML", "<p>x")), .html) }
    func testSniffHTML() throws {
        XCTAssertEqual(FileKind.classify(try file("page", "\u{FEFF}  \n<!DOCTYPE html><html></html>")), .html)
    }
    func testSVGIsHTML() throws { XCTAssertEqual(FileKind.classify(try file("logo.svg", "<svg/>")), .html) }
    func testMarkdown() throws { XCTAssertEqual(FileKind.classify(try file("README.md", "# Hi")), .markdown) }
    func testJSON() throws { XCTAssertEqual(FileKind.classify(try file("data.json", "{}")), .json) }
    func testCSVandTSV() throws {
        XCTAssertEqual(FileKind.classify(try file("a.csv", "a,b")), .csv(separator: ","))
        XCTAssertEqual(FileKind.classify(try file("a.tsv", "a\tb")), .csv(separator: "\t"))
    }
    func testCode() throws { XCTAssertEqual(FileKind.classify(try file("x.py", "print(1)")), .code(language: "python")) }
    func testPlainText() throws { XCTAssertEqual(FileKind.classify(try file("notes.txt")), .text) }
    func testUnknownExtensionUTF8IsText() throws { XCTAssertEqual(FileKind.classify(try file("a.weird", "just words")), .text) }
    func testBinaryUnknown() throws {
        let bytes = Data((0..<4096).map { UInt8(($0 * 37 + 11) % 256) })
        XCTAssertEqual(FileKind.classify(try file("blob.bin", data: bytes)), .unknown)
    }
    func testPDFIsQuickLook() throws { XCTAssertEqual(FileKind.classify(try file("doc.pdf", "%PDF-1.4")), .quickLook) }
    func testDocxIsQuickLook() throws { XCTAssertEqual(FileKind.classify(try file("doc.docx", data: Data([0x50, 0x4B, 3, 4]))), .quickLook) }
    func testImageIsQuickLook() throws { XCTAssertEqual(FileKind.classify(try file("p.PNG", data: Data([0x89, 0x50, 0x4E, 0x47]))), .quickLook) }
    func testZip() throws { XCTAssertEqual(FileKind.classify(try file("site.zip", data: Data([0x50, 0x4B, 3, 4]))), .zip) }
    func testFolder() throws {
        let sub = dir.appendingPathComponent("site.d")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        XCTAssertEqual(FileKind.classify(sub), .folder)
    }
    func testUnicodePath() throws {
        XCTAssertEqual(FileKind.classify(try file("Ünïcødé #1/页面.html", "<p>")), .html)
    }
    func testLanguages() {
        XCTAssertEqual(Languages.language(forExtension: "JS"), "javascript")
        XCTAssertEqual(Languages.language(forExtension: "swift"), "swift")
        XCTAssertEqual(Languages.language(forExtension: "yml"), "yaml")
        XCTAssertNil(Languages.language(forExtension: "docx"))
    }
}
