import XCTest
@testable import Viewer

final class JSONNodeTests: XCTestCase {
    func parse(_ s: String) throws -> JSONNode { try JSONNode.parse(Data(s.utf8)) }

    func testKeyOrderKept() throws {
        guard case .object(let pairs) = try parse(#"{"zeta": 1, "alpha": 2, "mid": 3}"#) else { return XCTFail() }
        XCTAssertEqual(pairs.map(\.0), ["zeta", "alpha", "mid"])
    }

    func testNestedAndTypes() throws {
        let node = try parse(#"{"a": [true, false, null, "s\"qé", {"b": -2.5e3}]}"#)
        guard case .object(let top) = node, case .array(let items) = top[0].1 else { return XCTFail() }
        XCTAssertEqual(items.count, 5)
        guard case .bool(true) = items[0], case .bool(false) = items[1], case .null = items[2] else { return XCTFail() }
        guard case .string(let s) = items[3] else { return XCTFail() }
        XCTAssertEqual(s, "s\"qé")
        guard case .object(let inner) = items[4], case .number(let n) = inner[0].1 else { return XCTFail() }
        XCTAssertEqual(n, "-2.5e3")
    }

    func testNumbersKeptAsWritten() throws {
        guard case .array(let a) = try parse("[1.50, 10, 0.1]"), case .number(let first) = a[0] else { return XCTFail() }
        XCTAssertEqual(first, "1.50")
    }

    func testSurrogatePairs() throws {
        guard case .string(let s) = try parse(#""😀""#) else { return XCTFail() }
        XCTAssertEqual(s, "😀")
    }

    func testInvalidThrows() {
        XCTAssertThrowsError(try parse(#"{"a": }"#))
        XCTAssertThrowsError(try parse("[1, 2"))
        XCTAssertThrowsError(try parse("[1] trailing"))
    }

    func testDeepNestingDoesNotCrash() {
        let deep = String(repeating: "[", count: 10_000) + String(repeating: "]", count: 10_000)
        XCTAssertThrowsError(try parse(deep))     // over the depth limit: error, not a stack overflow
    }
}
