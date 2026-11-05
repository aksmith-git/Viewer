import Foundation

/// What is open right now: the top-level item the user opened (file, folder or zip) and any
/// files opened from inside it. Holds the security scope for the top-level item while it is open.
@MainActor
final class OpenController: ObservableObject {
    @Published var opened: URL?
    @Published var children: [URL] = []
    /// Folders pages may load files from: the opened folder and any zips unpacked while browsing it.
    private(set) var siteRoots: [URL] = []
    private var scoped: URL?
    private let recents: RecentsStore
    let importedRoot: URL

    init(recents: RecentsStore, importedRoot: URL = OpenController.defaultImportedRoot) {
        self.recents = recents
        self.importedRoot = importedRoot
        recents.onEvict = { [weak self] item in self?.deleteImportedCopy(of: item) }
    }

    /// Open a file or folder from the picker, the share sheet, or recents.
    func open(_ url: URL) {
        close()
        let target = importIfInbox(url)
        if target.startAccessingSecurityScopedResource() { scoped = target }
        recents.add(target)
        children = []
        siteRoots = []
        opened = target
    }

    func noteSiteRoot(_ url: URL) {
        if !siteRoots.contains(where: { $0.standardizedFileURL == url.standardizedFileURL }) { siteRoots.append(url) }
    }

    /// Where an HTML file may read from: the widest known root containing it (so ../ works from
    /// subfolders), else the file's own folder.
    func readRoot(for file: URL) -> URL {
        siteRoots.filter { NavigationPolicy.isInside(file, $0) }
            .min { NavigationPolicy.canonical($0).count < NavigationPolicy.canonical($1).count }
            ?? file.deletingLastPathComponent()
    }

    func close() {
        scoped?.stopAccessingSecurityScopedResource()
        scoped = nil
        opened = nil
        children = []
        siteRoots = []
    }

    /// Files copied to us by "Open in…" land in Documents/Inbox, which iOS may clear. Move them to
    /// Application Support/Imported/<uuid>/ so they stay openable from recents.
    private func importIfInbox(_ url: URL) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let inbox = docs.appendingPathComponent("Inbox").standardizedFileURL.path
        guard url.standardizedFileURL.path.hasPrefix(inbox + "/") else { return url }
        let dest = importedRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            let moved = dest.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: moved)
            return moved
        } catch {
            return url
        }
    }

    nonisolated static var defaultImportedRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Imported", isDirectory: true)
    }

    /// Removes a recent and, if Viewer holds its only copy, the imported file too.
    func forget(_ item: RecentItem) {
        recents.remove(item.id)
        deleteImportedCopy(of: item)
    }

    /// Imported copies live in Imported/<uuid>/; delete the folder unless that file is open now.
    private func deleteImportedCopy(of item: RecentItem) {
        let file = URL(fileURLWithPath: item.path)
        guard NavigationPolicy.isInside(file, importedRoot) else { return }
        if let opened, NavigationPolicy.canonical(opened) == NavigationPolicy.canonical(file) { return }
        try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
    }
}
