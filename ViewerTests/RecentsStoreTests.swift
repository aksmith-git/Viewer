import XCTest
@testable import Viewer

@MainActor
final class RecentsStoreTests: XCTestCase {
    var dir: URL!
    var storeFile: URL { dir.appendingPathComponent("recents.json") }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func make(_ name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data("x".utf8).write(to: url)
        return url
    }

    func testAddAndOrder() throws {
        let store = RecentsStore(fileURL: storeFile)
        store.add(try make("a.txt"))
        store.add(try make("b.txt"))
        XCTAssertEqual(store.items.map(\.name), ["b.txt", "a.txt"])
    }

    func testDedupeSamePath() throws {
        let store = RecentsStore(fileURL: storeFile)
        let a = try make("a.txt")
        store.add(a)
        store.add(try make("b.txt"))
        store.add(a)
        XCTAssertEqual(store.items.map(\.name), ["a.txt", "b.txt"])
    }

    func testCap50DropsOldestUnpinned() throws {
        let store = RecentsStore(fileURL: storeFile)
        for i in 0..<52 { store.add(try make("f\(i).txt")) }
        XCTAssertEqual(store.items.count, 50)
        XCTAssertFalse(store.items.contains { $0.name == "f0.txt" || $0.name == "f1.txt" })
        XCTAssertEqual(store.items.first?.name, "f51.txt")
    }

    func testPinnedFirstAndKeptWhenCapped() throws {
        let store = RecentsStore(fileURL: storeFile)
        store.add(try make("keep.txt"))
        store.togglePin(store.items[0].id)
        for i in 0..<60 { store.add(try make("f\(i).txt")) }
        XCTAssertEqual(store.items.count, 50)
        XCTAssertEqual(store.items.first?.name, "keep.txt")
        XCTAssertTrue(store.items.first!.pinned)
    }

    func testRemove() throws {
        let store = RecentsStore(fileURL: storeFile)
        store.add(try make("a.txt"))
        store.remove(store.items[0].id)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testPersistsAcrossInstances() throws {
        let store = RecentsStore(fileURL: storeFile)
        store.add(try make("a.txt"))
        store.togglePin(store.items[0].id)
        let again = RecentsStore(fileURL: storeFile)
        XCTAssertEqual(again.items.map(\.name), ["a.txt"])
        XCTAssertTrue(again.items[0].pinned)
        XCTAssertEqual(again.resolve(again.items[0])?.lastPathComponent, "a.txt")
    }

    func testRefreshMissingPublishesSet() async throws {
        let store = RecentsStore(fileURL: storeFile)
        let a = try make("here.txt"), b = try make("gone2.txt")
        store.add(a); store.add(b)
        try FileManager.default.removeItem(at: b)
        await store.refreshMissing()
        XCTAssertEqual(store.missing, [store.items.first { $0.name == "gone2.txt" }!.id])
    }

    func testMissingFileFlagged() throws {
        let store = RecentsStore(fileURL: storeFile)
        let a = try make("gone.txt")
        store.add(a)
        try FileManager.default.removeItem(at: a)
        XCTAssertTrue(store.isMissing(store.items[0]))
        XCTAssertNil(store.resolve(store.items[0]))
    }
}
