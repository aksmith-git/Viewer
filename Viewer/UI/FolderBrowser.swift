import SwiftUI

/// Lists a folder (or an unpacked zip). Folders first, then files, in Finder order.
struct FolderBrowser: View {
    let folder: URL
    let onOpen: (URL) -> Void
    @State private var entries: [Entry] = []
    @State private var search = ""
    @State private var showHidden = false

    struct Entry: Identifiable, Hashable {
        let url: URL
        let isFolder: Bool
        let detail: String
        var id: URL { url }
    }

    private var index: URL? {
        entries.first { ["index.html", "index.htm"].contains($0.url.lastPathComponent.lowercased()) }?.url
    }

    private var shown: [Entry] {
        search.isEmpty ? entries : entries.filter { $0.url.lastPathComponent.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            if let index, search.isEmpty {
                Section {
                    Button { onOpen(index) } label: {
                        HStack(spacing: 14) {
                            KindBadge(style: KindStyle(url: index), size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Open Website").font(.headline)
                                Text("Runs \(index.lastPathComponent) with its styles and scripts")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            Section {
                ForEach(shown) { entry in
                    Button { onOpen(entry.url) } label: {
                        HStack(spacing: 12) {
                            KindBadge(style: KindStyle(url: entry.url), size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                                Text(entry.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                if !entries.isEmpty {
                    Text(summary).frame(maxWidth: .infinity)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("Empty Folder", systemImage: "folder", description: Text("There's nothing in this folder."))
            }
        }
        .searchable(text: $search, prompt: "Search")
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Toggle(isOn: $showHidden) { Label("Show Hidden Files", systemImage: "eye") }
            }
        }
        .task(id: showHidden) { entries = Self.load(folder, showHidden: showHidden) }
    }

    private var summary: String {
        let folders = entries.filter(\.isFolder).count
        let files = entries.count - folders
        var parts: [String] = []
        if folders > 0 { parts.append(folders == 1 ? "1 folder" : "\(folders) folders") }
        if files > 0 { parts.append(files == 1 ? "1 file" : "\(files) files") }
        return parts.joined(separator: ", ")
    }

    static func load(_ folder: URL, showHidden: Bool) -> [Entry] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: showHidden ? [] : [.skipsHiddenFiles])) ?? []
        return urls.map { url in
            let v = try? url.resourceValues(forKeys: Set(keys))
            let isFolder = v?.isDirectory == true
            let detail: String
            if isFolder {
                let n = (try? FileManager.default.contentsOfDirectory(atPath: url.path).filter { !$0.hasPrefix(".") }.count) ?? 0
                detail = n == 1 ? "1 item" : "\(n) items"
            } else {
                detail = ByteCountFormatter.string(fromByteCount: Int64(v?.fileSize ?? 0), countStyle: .file)
            }
            return Entry(url: url, isFolder: isFolder, detail: detail)
        }
        .sorted { a, b in
            a.isFolder != b.isFolder ? a.isFolder
                : a.url.lastPathComponent.localizedStandardCompare(b.url.lastPathComponent) == .orderedAscending
        }
    }
}
