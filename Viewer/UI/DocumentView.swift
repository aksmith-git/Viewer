import SwiftUI

/// Shows one file or folder, choosing the viewer from its `FileKind`.
struct DocumentView: View {
    let url: URL
    @EnvironmentObject private var opener: OpenController

    var body: some View {
        content
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var content: some View {
        switch FileKind.classify(url) {
        case .folder:
            FolderBrowser(folder: url) { opener.children.append($0) }
                .onAppear { opener.noteSiteRoot(url) }
        case .zip:
            ZipView(zip: url)
        case .html:
            WebViewer(file: url, root: opener.readRoot(for: url)).id(url)
        default:
            PlaceholderView(url: url)
        }
    }
}

/// Unpacks a zip (once) and shows its contents.
struct ZipView: View {
    let zip: URL
    @EnvironmentObject private var opener: OpenController
    @State private var root: URL?
    @State private var failure: String?

    var body: some View {
        Group {
            if let root {
                FolderBrowser(folder: root) { opener.children.append($0) }
            } else if let failure {
                ContentUnavailableView("Can't Open Zip", systemImage: "doc.zipper", description: Text(failure))
            } else {
                ProgressView("Unpacking…")
            }
        }
        .task {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let zip = zip
            do {
                let r = try await Task.detached { try ZipExtractor.extract(zip, cachesRoot: caches) }.value
                opener.noteSiteRoot(r)
                root = r
            } catch ZipError.unsafePath {
                failure = "This zip tries to put files outside its own folder, so Viewer won't unpack it."
            } catch {
                failure = "The zip is damaged or in a format Viewer can't read."
            }
        }
    }
}

struct PlaceholderView: View {
    let url: URL
    var body: some View {
        let style = KindStyle(url: url)
        VStack(spacing: 12) {
            KindBadge(style: style, size: 64)
            Text(url.lastPathComponent).font(.headline)
            Text(style.label).foregroundStyle(.secondary)
        }
    }
}
