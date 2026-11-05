import XCTest
@testable import Viewer

final class CSVParserTests: XCTestCase {
    func testQuotedComma() {
        XCTAssertEqual(CSVParser.parse("a,\"b,c\",d", separator: ",", maxRows: 10).rows, [["a", "b,c", "d"]])
    }
    func testEscapedQuote() {
        XCTAssertEqual(CSVParser.parse("\"say \"\"hi\"\"\",x", separator: ",", maxRows: 10).rows, [["say \"hi\"", "x"]])
    }
    func testNewlineInQuotes() {
        XCTAssertEqual(CSVParser.parse("\"line1\nline2\",b\nc,d", separator: ",", maxRows: 10).rows, [["line1\nline2", "b"], ["c", "d"]])
    }
    func testCRLF() {
        XCTAssertEqual(CSVParser.parse("a,b\r\nc,d\r\n", separator: ",", maxRows: 10).rows, [["a", "b"], ["c", "d"]])
    }
    func testTSV() {
        XCTAssertEqual(CSVParser.parse("a\tb,c\nd\te", separator: "\t", maxRows: 10).rows, [["a", "b,c"], ["d", "e"]])
    }
    func testEmptyFields() {
        XCTAssertEqual(CSVParser.parse("a,,c\n,,", separator: ",", maxRows: 10).rows, [["a", "", "c"], ["", "", ""]])
    }
    func testMaxRowsTruncates() {
        let text = (0..<100).map { "\($0),x" }.joined(separator: "\n")
        let r = CSVParser.parse(text, separator: ",", maxRows: 10)
        XCTAssertEqual(r.rows.count, 10)
        XCTAssertTrue(r.truncated)
        XCTAssertFalse(CSVParser.parse("a\nb", separator: ",", maxRows: 10).truncated)
    }
}
