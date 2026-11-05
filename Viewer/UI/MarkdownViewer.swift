import SwiftUI

/// Markdown rendered like a good README, with coloured code blocks and local images.
struct MarkdownViewer: View {
    let url: URL
    let root: URL
    @EnvironmentObject private var opener: OpenController
    @StateObject private var web: StaticWeb
    @AppStorage("markdownSize") private var size = 17.0
    @State private var showSource = false
    @State private var wrapUnused = true

    init(url: URL, root: URL) {
        self.url = url
        self.root = root
        _web = StateObject(wrappedValue: StaticWeb(scripts: ["marked.js", "highlight.min.js", "viewer-markdown.js"],
                                                   css: MarkdownViewer.css, siteRoot: root))
    }

    var body: some View {
        Group {
            if showSource {
                CodeViewer(url: url, language: "markdown")
            } else {
                StaticWebHost(web: web)
                    .ignoresSafeArea(edges: .bottom)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            TextOptionsMenu(wrap: $wrapUnused, size: $size, showWrap: false, find: web.find, copy: copy)
                        }
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $showSource) {
                    Text("Preview").tag(false)
                    Text("Source").tag(true)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .task(id: url) { load() }
        .onChange(of: size) { web.run("viewerSetSize(\(size))") }
    }

    private func load() {
        web.onLink = { link in
            if let file = SiteURL.file(for: link, root: root) {
                if FileManager.default.fileExists(atPath: file.path) { opener.children.append(file) }
            } else if ["http", "https", "mailto", "tel"].contains(link.scheme?.lowercased() ?? "") {
                UIApplication.shared.open(link)
            }
        }
        let text = (try? TextLoader.load(url, limit: CodeViewer.textLimit).text) ?? ""
        web.load(html: "<!doctype html><html><head><meta charset=utf-8><meta name=viewport content='width=device-width, initial-scale=1'></head><body><article id=md></article></body></html>",
                 baseURL: SiteURL.url(for: url, root: root))
        web.run("viewerSetSize(\(size)); viewerRenderMarkdown(\(StaticWeb.jsonString(text)))")
    }

    private func copy() {
        UIPasteboard.general.string = (try? TextLoader.load(url, limit: CodeViewer.textLimit).text) ?? ""
    }

    static var css: String {
        StaticWeb.highlightCSS + """

        :root { color-scheme: light dark; --size: 17px; --fg: #1f2328; --muted: #59636e; --border: rgba(127,127,127,.25);
                --code-bg: rgba(127,127,127,.12); --link: #0969da; }
        @media (prefers-color-scheme: dark) { :root { --fg: #e6edf3; --muted: #9198a1; --link: #4493f8; } }
        html, body { margin: 0; background: transparent; -webkit-text-size-adjust: none; }
        body { font: var(--size)/1.6 -apple-system, system-ui, sans-serif; color: var(--fg); }
        article { max-width: 760px; margin: 0 auto; padding: 16px 20px 60px; word-wrap: break-word; }
        h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.4em 0 .6em; font-weight: 650; letter-spacing: -0.01em; }
        h1 { font-size: 1.9em; padding-bottom: .3em; border-bottom: 1px solid var(--border); margin-top: .4em; }
        h2 { font-size: 1.45em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
        h3 { font-size: 1.2em; } h4 { font-size: 1em; } h5, h6 { font-size: .9em; color: var(--muted); }
        p, ul, ol, blockquote, table, pre { margin: 0 0 1em; }
        a { color: var(--link); text-decoration: none; }
        img { max-width: 100%; border-radius: 6px; }
        blockquote { padding: 0 1em; color: var(--muted); border-left: .25em solid var(--border); }
        code { font: .86em ui-monospace, "SF Mono", Menlo, monospace; background: var(--code-bg); padding: .15em .4em; border-radius: 6px; }
        pre { background: var(--code-bg); border-radius: 10px; padding: 14px 16px; overflow-x: auto; line-height: 1.45; }
        pre code { background: transparent !important; padding: 0 !important; font-size: .82em; }
        table { border-collapse: collapse; display: block; overflow-x: auto; }
        th, td { border: 1px solid var(--border); padding: 6px 12px; }
        th { font-weight: 600; background: var(--code-bg); }
        hr { border: 0; height: 1px; background: var(--border); margin: 1.6em 0; }
        li + li { margin-top: .25em; }
        input[type=checkbox] { margin-right: .4em; }
        """
    }
}
