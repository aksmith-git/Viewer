import SwiftUI
import UniformTypeIdentifiers

/// Shows one file or folder, choosing the viewer from its `FileKind`.
struct DocumentView: View {
    let url: URL
    @EnvironmentObject private var opener: OpenController

    var body: some View {
        content
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
    }

    static func size(of url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
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
        case .markdown:
            MarkdownViewer(url: url, root: opener.readRoot(for: url)).id(url)
        case .code(let language):
            CodeViewer(url: url, language: language).id(url)
        case .text:
            CodeViewer(url: url, language: nil).id(url)
        case .json:
            if Self.size(of: url) > JSONTreeView.treeLimit {
                CodeViewer(url: url, language: "json").id(url)
            } else {
                JSONTreeView(url: url).id(url)
            }
        case .csv(let separator):
            CSVGridView(url: url, separator: separator).id(url)
        case .quickLook:
            let type = UTType(filenameExtension: url.pathExtension.lowercased())
            if type?.conforms(to: .pdf) == true {
                PDFDocumentView(url: url).id(url)
            } else if type?.conforms(to: .image) == true && type?.conforms(to: .gif) != true {
                ImageViewer(url: url).id(url)
            } else if type?.conforms(to: .audiovisualContent) == true || type?.conforms(to: .audio) == true {
                MediaPlayerView(url: url).id(url)
            } else {
                QuickLookView(url: url).ignoresSafeArea(edges: .bottom).id(url)
            }
        case .unknown:
            InfoView(url: url)
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
            } catch ZipError.tooLarge {
                failure = "This zip would unpack to more than 2 GB, so Viewer won't open it."
            } catch ZipError.unsafePath {
                failure = "This zip tries to put files outside its own folder, so Viewer won't unpack it."
            } catch {
                failure = "The zip is damaged or in a format Viewer can't read."
            }
        }
    }
}
