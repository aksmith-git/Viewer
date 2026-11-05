import XCTest
@testable import Viewer

final class NavigationPolicyTests: XCTestCase {
    let root = URL(fileURLWithPath: "/tmp/site", isDirectory: true)

    func testInsideRoot() {
        XCTAssertEqual(NavigationPolicy.decide(url: root.appendingPathComponent("about/index.html"), root: root, isMainFrame: true), .allow)
    }

    func testRootItselfAllowed() {
        XCTAssertEqual(NavigationPolicy.decide(url: root.appendingPathComponent("index.html"), root: root, isMainFrame: true), .allow)
    }

    func testInsideRootWithSpaces() {
        let spaced = URL(fileURLWithPath: "/tmp/My Site #1", isDirectory: true)
        let page = URL(string: "file:///tmp/My%20Site%20%231/page%20two.html#top")!
        XCTAssertEqual(NavigationPolicy.decide(url: page, root: spaced, isMainFrame: true), .allow)
    }

    func testOutsideRootCancelled() {
        let escape = URL(string: "file:///tmp/site/../secret.html")!
        XCTAssertEqual(NavigationPolicy.decide(url: escape, root: root, isMainFrame: true), .cancel)
        XCTAssertEqual(NavigationPolicy.decide(url: URL(fileURLWithPath: "/tmp/site-other/x.html"), root: root, isMainFrame: true), .cancel)
    }

    func testHTTPMainFrameExternal() {
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "https://apple.com")!, root: root, isMainFrame: true), .openExternally)
    }

    func testHTTPSubresourceAllowed() {
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "https://www.youtube.com/embed/x")!, root: root, isMainFrame: false), .allow)
    }

    func testMailtoExternal() {
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "mailto:a@b.c")!, root: root, isMainFrame: true), .openExternally)
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "tel:123")!, root: root, isMainFrame: true), .openExternally)
    }

    func testDataAndAboutAllowed() {
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "about:blank")!, root: root, isMainFrame: false), .allow)
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "data:text/html,hi")!, root: root, isMainFrame: false), .allow)
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "blob:null/1234")!, root: root, isMainFrame: false), .allow)
    }

    func testJavascriptSchemeCancelled() {
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "javascript:alert(1)")!, root: root, isMainFrame: true), .cancel)
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "weird-app://x")!, root: root, isMainFrame: true), .cancel)
    }
}
