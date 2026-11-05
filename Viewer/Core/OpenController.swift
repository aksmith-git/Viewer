import Foundation

/// What is open right now: the top-level item the user opened (file, folder or zip) and any
/// files opened from inside it. Holds the security scope for the top-level item while it is open.
@MainActor
final class OpenController: ObservableObject {
    @Published var opened: URL?
    @Published var children: [URL] = []
    /// The folder pages are allowed to load files from: the opened folder or the unpacked zip.
    private(set) var siteRoot: URL?
    private var scoped: URL?
    private let recents: RecentsStore

    init(recents: RecentsStore) { self.recents = recents }

    /// Open a file or folder from the picker, the share sheet, or recents.
    func open(_ url: URL) {
        close()
        let target = importIfInbox(url)
        if target.startAccessingSecurityScopedResource() { scoped = target }
        recents.add(target)
        children = []
        siteRoot = nil
        opened = target
    }

    func noteSiteRoot(_ url: URL) {
        if siteRoot == nil || !url.standardizedFileURL.path.hasPrefix(siteRoot!.standardizedFileURL.path + "/") {
            siteRoot = url
        }
    }

    /// Where an HTML file may read from: the site root when the file is inside it, else its own folder.
    func readRoot(for file: URL) -> URL {
        if let root = siteRoot, file.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/") { return root }
        return file.deletingLastPathComponent()
    }

    func close() {
        scoped?.stopAccessingSecurityScopedResource()
        scoped = nil
        opened = nil
        children = []
        siteRoot = nil
    }

    /// Files copied to us by "Open in…" land in Documents/Inbox, which iOS may clear. Move them to
    /// Application Support/Imported/<uuid>/ so they stay openable from recents.
    private func importIfInbox(_ url: URL) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let inbox = docs.appendingPathComponent("Inbox").standardizedFileURL.path
        guard url.standardizedFileURL.path.hasPrefix(inbox + "/") else { return url }
        let dest = Self.importedRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            let moved = dest.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: moved)
            return moved
        } catch {
            return url
        }
    }

    static var importedRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Imported", isDirectory: true)
    }

    /// Removes a recent and, if Viewer holds its only copy, the imported file too.
    func forget(_ item: RecentItem) {
        recents.remove(item.id)
        let root = Self.importedRoot.standardizedFileURL.path
        if item.path.hasPrefix(root + "/") {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: item.path).deletingLastPathComponent())
        }
    }
}
