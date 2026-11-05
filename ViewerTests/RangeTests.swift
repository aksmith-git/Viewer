import XCTest
@testable import Viewer

final class RangeTests: XCTestCase {
    func testFullRange() { XCTAssertTrue(SiteSchemeHandler.parse(range: "bytes=0-99", size: 1000)! == (0, 99)) }
    func testOpenEnded() { XCTAssertTrue(SiteSchemeHandler.parse(range: "bytes=900-", size: 1000)! == (900, 999)) }
    func testSuffix() { XCTAssertTrue(SiteSchemeHandler.parse(range: "bytes=-100", size: 1000)! == (900, 999)) }
    func testClampsEnd() { XCTAssertTrue(SiteSchemeHandler.parse(range: "bytes=10-5000", size: 1000)! == (10, 999)) }
    func testInvalid() {
        XCTAssertNil(SiteSchemeHandler.parse(range: "bytes=1000-", size: 1000))
        XCTAssertNil(SiteSchemeHandler.parse(range: "bytes=5-2", size: 1000))
        XCTAssertNil(SiteSchemeHandler.parse(range: "bytes=0-1,5-6", size: 1000))
        XCTAssertNil(SiteSchemeHandler.parse(range: "items=0-1", size: 1000))
    }
}
