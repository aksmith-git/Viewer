import XCTest
@testable import Viewer

@MainActor
final class OpenControllerTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("A/sub"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func testSiteRootNotNarrowedAfterVisitingZip() {
        let opener = OpenController(recents: RecentsStore(fileURL: dir.appendingPathComponent("r.json")))
        let a = dir.appendingPathComponent("A"), sub = a.appendingPathComponent("sub")
        let zipRoot = dir.appendingPathComponent("Extracted/abc")
        opener.noteSiteRoot(a)
        opener.noteSiteRoot(sub)          // browsing a subfolder
        opener.noteSiteRoot(zipRoot)      // a zip inside it
        opener.noteSiteRoot(sub)          // back again
        // a page in A/sub that uses ../css must still be able to reach A
        XCTAssertEqual(opener.readRoot(for: sub.appendingPathComponent("page.html")).standardizedFileURL.path, a.standardizedFileURL.path)
        XCTAssertEqual(opener.readRoot(for: zipRoot.appendingPathComponent("index.html")).standardizedFileURL.path, zipRoot.standardizedFileURL.path)
    }

    func testEvictedImportedCopyIsDeleted() throws {
        let store = RecentsStore(fileURL: dir.appendingPathComponent("r.json"))
        let opener = OpenController(recents: store, importedRoot: dir.appendingPathComponent("Imported"))
        let importedDir = dir.appendingPathComponent("Imported/one")
        try FileManager.default.createDirectory(at: importedDir, withIntermediateDirectories: true)
        let imported = importedDir.appendingPathComponent("mail.pdf")
        try Data("x".utf8).write(to: imported)
        store.add(imported)
        for i in 0..<store.limit {
            let f = dir.appendingPathComponent("f\(i).txt"); try Data("x".utf8).write(to: f); store.add(f)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: importedDir.path), "imported copy should go when it falls off recents")
        _ = opener
    }

    func testForgetKeepsCurrentlyOpenImportedFile() throws {
        let store = RecentsStore(fileURL: dir.appendingPathComponent("r.json"))
        let opener = OpenController(recents: store, importedRoot: dir.appendingPathComponent("Imported"))
        let importedDir = dir.appendingPathComponent("Imported/two")
        try FileManager.default.createDirectory(at: importedDir, withIntermediateDirectories: true)
        let imported = importedDir.appendingPathComponent("doc.txt")
        try Data("x".utf8).write(to: imported)
        opener.open(imported)
        opener.forget(store.items[0])
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.path))
    }
}
