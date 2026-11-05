import SwiftUI
import UniformTypeIdentifiers

/// Recents and favourites, plus Browse.
struct HomeView: View {
    @EnvironmentObject private var recents: RecentsStore
    @EnvironmentObject private var opener: OpenController
    @State private var browsing = false
    @State private var search = ""
    @State private var missing: RecentItem?
    @State private var showingAbout = false
    var selection: Binding<String?>? = nil      // iPad sidebar selection (item path)

    private var filtered: [RecentItem] {
        search.isEmpty ? recents.items : recents.items.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        Group {
            if recents.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Viewer")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { browsing = true } label: { Label("Browse", systemImage: "folder") }
                    .keyboardShortcut("o", modifiers: .command)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button { showingAbout = true } label: { Label("About Viewer", systemImage: "info.circle") }
            }
        }
        .fileImporter(isPresented: $browsing, allowedContentTypes: [.item, .folder]) { result in
            if case .success(let url) = result { opener.open(url) }
        }
        .alert("Can't Find “\(missing?.name ?? "")”", isPresented: Binding(get: { missing != nil }, set: { if !$0 { missing = nil } }),
               presenting: missing) { item in
            Button("Remove from Recents", role: .destructive) { opener.forget(item) }
            Button("Browse…") { browsing = true }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It may have been moved, renamed or deleted.")
        }
        .sheet(isPresented: $showingAbout) { AboutView() }
        .task { if UserDefaults.standard.bool(forKey: "showAbout") { showingAbout = true } }   // screenshots
    }

    private var list: some View {
        List(selection: selection) {
            let pinned = filtered.filter(\.pinned)
            let recent = filtered.filter { !$0.pinned }
            if !pinned.isEmpty {
                Section("Pinned") { ForEach(pinned) { row($0) } }
            }
            if !recent.isEmpty {
                Section("Recent") { ForEach(recent) { row($0) } }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, prompt: "Search Recents")
        .animation(.default, value: recents.items)
    }

    private func row(_ item: RecentItem) -> some View {
        let url = URL(fileURLWithPath: item.path)
        let isMissing = recents.isMissing(item)
        return Button {
            if let resolved = recents.resolve(item) { opener.open(resolved) } else { missing = item }
        } label: {
            RecentRow(item: item, style: KindStyle(url: url), missing: isMissing)
        }
        .tag(item.path)
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button { recents.togglePin(item.id) } label: {
                Label(item.pinned ? "Unpin" : "Pin", systemImage: item.pinned ? "pin.slash" : "pin")
            }.tint(.yellow)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { opener.forget(item) } label: { Label("Remove", systemImage: "trash") }
        }
        .contextMenu {
            Button { recents.togglePin(item.id) } label: {
                Label(item.pinned ? "Unpin" : "Pin", systemImage: item.pinned ? "pin.slash" : "pin")
            }
            Button(role: .destructive) { opener.forget(item) } label: { Label("Remove from Recents", systemImage: "trash") }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Open Anything", systemImage: "doc.viewfinder")
        } description: {
            Text("Web pages with JavaScript, PDFs, Office and iWork files, code, Markdown, zips and more.\n\nBrowse your files, or share a file to Viewer from any app.")
        } actions: {
            Button { browsing = true } label: {
                Label("Browse Files", systemImage: "folder").padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

struct RecentRow: View {
    let item: RecentItem
    let style: KindStyle
    let missing: Bool

    var body: some View {
        HStack(spacing: 12) {
            KindBadge(style: style)
                .saturation(missing ? 0 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Group {
                    if missing {
                        Text("Not found")
                    } else {
                        Text("\(style.label) · ") + Text(item.opened, format: .relative(presentation: .named))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if item.pinned {
                Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.yellow).accessibilityLabel("Pinned")
            }
        }
        .padding(.vertical, 2)
        .opacity(missing ? 0.5 : 1)
        .contentShape(Rectangle())
    }
}
