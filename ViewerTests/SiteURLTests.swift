import XCTest
@testable import Viewer

final class SiteURLTests: XCTestCase {
    let root = URL(fileURLWithPath: "/tmp/My Site #1", isDirectory: true)

    func testRoundTrip() {
        let file = root.appendingPathComponent("pages/über uns.html")
        let url = SiteURL.url(for: file, root: root)
        XCTAssertEqual(url.scheme, "viewer")
        XCTAssertEqual(SiteURL.file(for: url, root: root)?.path, file.path)
    }

    func testRelativeResolution() {
        let page = SiteURL.url(for: root.appendingPathComponent("pages/a.html"), root: root)
        let css = URL(string: "../css/site.css", relativeTo: page)!.absoluteURL
        XCTAssertEqual(SiteURL.file(for: css, root: root)?.path, root.appendingPathComponent("css/site.css").path)
    }

    func testEscapeRejected() {
        let evil = URL(string: "viewer://local/../../etc/passwd")!
        XCTAssertNil(SiteURL.file(for: evil, root: root))
        let encoded = URL(string: "viewer://local/%2E%2E/%2E%2E/etc/passwd")!
        XCTAssertNil(SiteURL.file(for: encoded, root: root))
    }

    func testDirectoryMapsToIndex() {
        XCTAssertEqual(SiteURL.file(for: URL(string: "viewer://local/docs/")!, root: root)?.lastPathComponent, "index.html")
    }

    func testQueryAndFragmentIgnored() {
        XCTAssertEqual(SiteURL.file(for: URL(string: "viewer://local/a.js?v=3#x")!, root: root)?.lastPathComponent, "a.js")
    }

    func testPolicyAllowsSiteURLsInsideRoot() {
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "viewer://local/x.html")!, root: root, isMainFrame: true), .allow)
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "viewer://local/../x.html")!, root: root, isMainFrame: true), .cancel)
    }

    func testMimeTypes() {
        XCTAssertEqual(SiteURL.mimeType(for: URL(fileURLWithPath: "/a/x.js")), "text/javascript")
        XCTAssertEqual(SiteURL.mimeType(for: URL(fileURLWithPath: "/a/x.mjs")), "text/javascript")
        XCTAssertEqual(SiteURL.mimeType(for: URL(fileURLWithPath: "/a/x.css")), "text/css")
        XCTAssertEqual(SiteURL.mimeType(for: URL(fileURLWithPath: "/a/x.HTML")), "text/html")
        XCTAssertEqual(SiteURL.mimeType(for: URL(fileURLWithPath: "/a/x.wasm")), "application/wasm")
        XCTAssertEqual(SiteURL.mimeType(for: URL(fileURLWithPath: "/a/x.unknownext")), "application/octet-stream")
    }
}
