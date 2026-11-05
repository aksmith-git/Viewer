import Foundation

struct RecentItem: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var path: String          // last known path, for de-duplication and display
    var bookmark: Data
    var pinned: Bool
    var opened: Date
}

/// Recently opened files and folders, kept as bookmarks so they reopen in place.
/// Pinned items come first, then most recent; at most `limit` items in total.
@MainActor
final class RecentsStore: ObservableObject {
    @Published private(set) var items: [RecentItem] = []
    /// Items whose files can't be found; refreshed off the main thread, never while drawing.
    @Published private(set) var missing: Set<UUID> = []
    private let fileURL: URL
    let limit = 50
    /// Called for items dropped by the size limit (not for explicit removes).
    var onEvict: ((RecentItem) -> Void)?

    init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([RecentItem].self, from: data) {
            items = saved
        }
    }

    static func standard() -> RecentsStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return RecentsStore(fileURL: support.appendingPathComponent("recents.json"))
    }

    func add(_ url: URL) {
        let path = url.standardizedFileURL.path
        guard let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        var item = RecentItem(id: UUID(), name: url.lastPathComponent, path: path, bookmark: bookmark, pinned: false, opened: Date())
        if let i = items.firstIndex(where: { $0.path == path }) {
            item = RecentItem(id: items[i].id, name: item.name, path: path, bookmark: bookmark, pinned: items[i].pinned, opened: item.opened)
            items.remove(at: i)
        }
        items.append(item)
        normalize()
    }

    func togglePin(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].pinned.toggle()
        normalize()
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func item(for url: URL) -> RecentItem? {
        items.first { $0.path == url.standardizedFileURL.path }
    }

    /// The item's current URL, or nil if it can't be found any more.
    func resolve(_ item: RecentItem) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: item.bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        else { return nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil),
           let i = items.firstIndex(where: { $0.id == item.id }) {
            items[i].bookmark = fresh
            items[i].path = url.standardizedFileURL.path
            save()
        }
        return url
    }

    func isMissing(_ item: RecentItem) -> Bool { resolve(item) == nil }

    func refreshMissing() async {
        let snapshot = items.map { ($0.id, $0.bookmark) }
        let gone = await Task.detached(priority: .utility) { () -> Set<UUID> in
            var result = Set<UUID>()
            for (id, bookmark) in snapshot {
                var stale = false
                guard let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale) else {
                    result.insert(id); continue
                }
                let scoped = url.startAccessingSecurityScopedResource()
                if !FileManager.default.fileExists(atPath: url.path) { result.insert(id) }
                if scoped { url.stopAccessingSecurityScopedResource() }
            }
            return result
        }.value
        if gone != missing { missing = gone }
    }

    private func normalize() {
        items.sort { a, b in a.pinned != b.pinned ? a.pinned : a.opened > b.opened }
        while items.count > limit, let last = items.lastIndex(where: { !$0.pinned }) {
            let evicted = items.remove(at: last)    // not inside onEvict?(…): that would skip the removal when nil
            onEvict?(evicted)
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: fileURL, options: .atomic) }
    }
}
