import SwiftUI

/// Code with syntax colours and line numbers, or plain text (language nil / "plaintext").
struct CodeViewer: View {
    let url: URL
    var language: String?
    @StateObject private var web: StaticWeb
    @AppStorage("codeWrap") private var codeWrap = false
    @AppStorage("textWrap") private var textWrap = true     // prose reads better wrapped
    private var isPlain: Bool { language == nil || language == "plaintext" }
    private var wrap: Binding<Bool> { isPlain ? $textWrap : $codeWrap }
    @AppStorage("codeSize") private var size = 13.0
    @State private var truncated = false
    @State private var failed = false

    init(url: URL, language: String?) {
        self.url = url
        self.language = language
        let plain = language == nil || language == "plaintext"
        _web = StateObject(wrappedValue: StaticWeb(scripts: plain ? ["viewer-code.js"] : ["highlight.min.js", "viewer-code.js"],
                                                   css: CodeViewer.css, extraLanguage: plain ? nil : language))
    }

    static let textLimit = 5 * 1024 * 1024
    static let highlightLimit = 2 * 1024 * 1024

    var body: some View {
        StaticWebHost(web: web)
            .ignoresSafeArea(edges: .bottom)
            .safeAreaInset(edge: .top, spacing: 0) {
                if truncated { NoticeBar(text: "Showing the first 5 MB of this file") }
            }
            .overlay {
                if failed {
                    ContentUnavailableView("Can't Read File", systemImage: "doc.questionmark",
                                           description: Text("Viewer couldn't read this file as text."))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { TextOptionsMenu(wrap: wrap, size: $size, find: web.find, copy: copyAll) }
            }
            .task(id: url) { await load() }
            .onChange(of: wrap.wrappedValue) { web.run("viewerSetWrap(\(wrap.wrappedValue))") }
            .onChange(of: size) { web.run("viewerSetSize(\(size))") }
    }

    private func load() async {
        let url = url
        guard let result = try? await Task.detached(operation: { try TextLoader.load(url, limit: Self.textLimit) }).value else {
            failed = true
            return
        }
        truncated = result.truncated
        let lang = result.text.utf8.count > Self.highlightLimit ? "plaintext" : (language ?? "plaintext")
        web.load(html: Self.template, baseURL: nil)
        web.run("viewerSetWrap(\(wrap.wrappedValue)); viewerSetSize(\(size)); viewerRender(\(StaticWeb.jsonString(result.text)), '\(lang)')")
    }

    private func copyAll() {
        web.webView.evaluateJavaScript("viewerCopyText()") { value, _ in
            if let s = value as? String { UIPasteboard.general.string = s }
        }
    }

    static let template = """
    <!doctype html><html><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=5">
    </head><body><div class="wrapper"><pre id="gutter" aria-hidden="true"></pre><pre><code id="code" class="hljs"></code></pre></div></body></html>
    """

    static var css: String {
        StaticWeb.highlightCSS + """

        :root { color-scheme: light dark; --size: 13px; }
        html, body { margin: 0; background: transparent; -webkit-text-size-adjust: none; }
        .wrapper { display: grid; grid-template-columns: auto 1fr; }
        pre { margin: 0; font: var(--size)/1.55 ui-monospace, "SF Mono", Menlo, monospace; padding: 12px 14px 40px; }
        #gutter { text-align: right; color: rgba(128,128,128,.55); user-select: none; -webkit-user-select: none;
                  padding-right: 10px; border-right: 1px solid rgba(128,128,128,.18); position: sticky; left: 0;
                  background: Canvas; z-index: 1; }
        pre:last-child { overflow-x: auto; }
        code { font: inherit; }
        code.hljs { background: transparent !important; padding: 0 !important; }
        body.wrap pre:last-child { white-space: pre-wrap; word-break: break-word; overflow-x: visible; }
        body.wrap #gutter { display: none; }
        body.wrap .wrapper { grid-template-columns: 1fr; }
        """
    }
}

/// Wrap, text size, find and copy — shared by the code, text and Markdown viewers.
struct TextOptionsMenu: View {
    @Binding var wrap: Bool
    @Binding var size: Double
    var showWrap = true
    let find: () -> Void
    let copy: () -> Void

    var body: some View {
        Menu {
            Section {
                Button(action: find) { Label("Find", systemImage: "magnifyingglass") }
                Button(action: copy) { Label("Copy All", systemImage: "doc.on.doc") }
            }
            Section {
                if showWrap { Toggle(isOn: $wrap) { Label("Wrap Lines", systemImage: "text.word.spacing") } }
                ControlGroup {
                    Button { size = max(9, size - 1) } label: { Label("Smaller", systemImage: "textformat.size.smaller") }
                    Button { size = min(28, size + 1) } label: { Label("Larger", systemImage: "textformat.size.larger") }
                } label: { Text("Text Size") }
            }
        } label: {
            Label("Options", systemImage: "ellipsis")
        }
    }
}
