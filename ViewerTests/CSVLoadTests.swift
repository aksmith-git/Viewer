import XCTest
@testable import Viewer

final class CSVLoadTests: XCTestCase {
    func testByteLimitMarksTruncated() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".csv")
        try Data((0..<2000).map { "\($0),value\n" }.joined().utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let table = try XCTUnwrap(CSVGridView.loadTable(url, separator: ",", byteLimit: 1000, maxRows: 50_000))
        XCTAssertTrue(table.truncated)              // cut by bytes, not rows
        XCTAssertLessThan(table.rows.count, 2000)
        XCTAssertEqual(table.rows.last?.count, 2)   // the partial last line is dropped, not shown broken
    }
}
