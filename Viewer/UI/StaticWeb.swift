import SwiftUI
import WebKit

/// A web view for content Viewer renders itself (code, Markdown): bundled scripts injected,
/// links handed back to the app, JavaScript calls queued until the page has loaded.
@MainActor
final class StaticWeb: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    var onLink: ((URL) -> Void)?
    private var loaded = false
    private var pending: [String] = []
    private let handler: SiteSchemeHandler?

    init(scripts: [String], css: String, siteRoot: URL? = nil, extraLanguage: String? = nil) {
        let config = WKWebViewConfiguration()
        handler = siteRoot.map { SiteSchemeHandler(root: $0) }
        if let handler { config.setURLSchemeHandler(handler, forURLScheme: SiteURL.scheme) }
        let controller = config.userContentController
        var sources = scripts.compactMap(Self.resource)
        if let lang = extraLanguage, let js = Self.highlightLanguage(lang) { sources.append(js) }
        for js in sources {
            controller.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        let style = "const s=document.createElement('style');s.textContent=\(Self.jsonString(css));document.head.appendChild(s);"
        controller.addUserScript(WKUserScript(source: style, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: config)
        webView.isFindInteractionEnabled = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        super.init()
        webView.navigationDelegate = self
    }

    func load(html: String, baseURL: URL?) {
        loaded = false
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func run(_ js: String) {
        if loaded { webView.evaluateJavaScript(js) } else { pending.append(js) }
    }

    func find() { webView.findInteraction?.presentFindNavigator(showingReplace: false) }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        let queued = pending
        pending = []
        for js in queued { webView.evaluateJavaScript(js) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        if action.navigationType == .linkActivated, let url = action.request.url {
            if url.fragment != nil, url.absoluteString.hasPrefix((webView.url?.absoluteString ?? "") + "#") { return .allow }
            onLink?(url)
            return .cancel
        }
        return .allow
    }

    // MARK: helpers

    private static var cache: [String: String] = [:]

    static func resource(_ name: String) -> String? {
        if let s = cache[name] { return s }
        let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
        guard let url = Bundle.main.url(forResource: parts[0], withExtension: parts.count > 1 ? parts[1] : nil),
              let s = try? String(contentsOf: url) else { return nil }
        cache[name] = s
        return s
    }

    /// highlight.min.js covers the common languages; others load from the hljs folder.
    static let commonLanguages: Set<String> = ["bash", "c", "cpp", "csharp", "css", "diff", "go", "graphql", "ini", "java",
        "javascript", "json", "kotlin", "less", "lua", "makefile", "markdown", "objectivec", "perl", "php", "php-template",
        "plaintext", "python", "python-repl", "r", "ruby", "rust", "scss", "shell", "sql", "swift", "typescript", "vbnet",
        "wasm", "xml", "yaml"]

    static func highlightLanguage(_ lang: String) -> String? {
        guard !commonLanguages.contains(lang),
              let dir = Bundle.main.url(forResource: "hljs", withExtension: nil) else { return nil }
        return try? String(contentsOf: dir.appendingPathComponent("\(lang).min.js"))
    }

    static func jsonString(_ s: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [s])) ?? Data("[\"\"]".utf8)
        let array = String(data: data, encoding: .utf8) ?? "[\"\"]"
        return String(array.dropFirst().dropLast())
    }

    /// highlight.js themes for light and dark, switched by the system appearance.
    static var highlightCSS: String {
        "@media (prefers-color-scheme: light) { \(resource("hl-light.css") ?? "") }\n"
            + "@media (prefers-color-scheme: dark) { \(resource("hl-dark.css") ?? "") }"
    }
}

struct StaticWebHost: UIViewRepresentable {
    let web: StaticWeb
    func makeUIView(context: Context) -> WKWebView { web.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// A slim banner pinned under the navigation bar.
struct NoticeBar: View {
    let text: String
    var symbol = "scissors"
    var body: some View {
        Label(text, systemImage: symbol)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.bar)
    }
}
