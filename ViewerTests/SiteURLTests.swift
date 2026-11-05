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
        let h = SiteURL.host(for: root)
        let evil = URL(string: "viewer://\(h)/../../etc/passwd")!
        XCTAssertNil(SiteURL.file(for: evil, root: root))
        let encoded = URL(string: "viewer://\(h)/%2E%2E/%2E%2E/etc/passwd")!
        XCTAssertNil(SiteURL.file(for: encoded, root: root))
    }

    func testDirectoryMapsToIndex() {
        XCTAssertEqual(SiteURL.file(for: URL(string: "viewer://\(SiteURL.host(for: root))/docs/")!, root: root)?.lastPathComponent, "index.html")
    }

    func testQueryAndFragmentIgnored() {
        XCTAssertEqual(SiteURL.file(for: URL(string: "viewer://\(SiteURL.host(for: root))/a.js?v=3#x")!, root: root)?.lastPathComponent, "a.js")
    }

    func testPolicyAllowsSiteURLsInsideRoot() {
        let h = SiteURL.host(for: root)
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "viewer://\(h)/x.html")!, root: root, isMainFrame: true), .allow)
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "viewer://\(h)/../x.html")!, root: root, isMainFrame: true), .cancel)
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "viewer://local/x.html")!, root: root, isMainFrame: true), .cancel)
    }

    func testHostDiffersPerRoot() {
        let other = URL(fileURLWithPath: "/tmp/Other Site", isDirectory: true)
        let a = SiteURL.url(for: root.appendingPathComponent("index.html"), root: root)
        let b = SiteURL.url(for: other.appendingPathComponent("index.html"), root: other)
        XCTAssertNotEqual(a.host, b.host)                       // separate origins = separate storage
        XCTAssertNil(SiteURL.file(for: b, root: root))         // another site's URL doesn't map into this root
    }

    func testMissingFileUnderPrivatePrefixIsInside() {
        // document-picker folders come as /private/var/...; a missing file can't have its symlinks resolved
        let privateRoot = URL(fileURLWithPath: "/private/tmp/site-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: privateRoot, withIntermediateDirectories: true)
        let missing = URL(fileURLWithPath: privateRoot.path).appendingPathComponent("css/nope.css")
        XCTAssertTrue(NavigationPolicy.isInside(missing, privateRoot))
        XCTAssertNotNil(SiteURL.file(for: SiteURL.url(for: missing, root: privateRoot), root: privateRoot))
    }

    func testRangeCappedForLargeFiles() {
        let r = SiteSchemeHandler.responseRange(header: "bytes=0-", size: 1_500_000_000, cap: 8 << 20)
        XCTAssertEqual(r?.start, 0)
        XCTAssertEqual(r?.end, (8 << 20) - 1)
        XCTAssertEqual(SiteSchemeHandler.responseRange(header: "bytes=100-199", size: 1000, cap: 8 << 20)?.end, 199)
        XCTAssertNil(SiteSchemeHandler.responseRange(header: nil, size: 1000, cap: 8 << 20))   // no Range: whole file
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
