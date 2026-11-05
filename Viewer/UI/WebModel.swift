import SwiftUI
import WebKit

struct ConsoleEntry: Identifiable, Equatable {
    let id = UUID()
    let level: String
    let message: String
    let time: Date
}

/// Owns the web view for one HTML document and everything the toolbar shows about it.
@MainActor
final class WebModel: NSObject, ObservableObject {
    let file: URL
    let root: URL
    let webView: WKWebView
    @Published var title = ""
    @Published var progress: Double = 0
    @Published var loading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var desktop = false
    @Published var console: [ConsoleEntry] = []
    @Published var missingFiles = false
    @Published var failed: String?
    private let handler: SiteSchemeHandler
    private var observations: [NSKeyValueObservation] = []

    var errorCount: Int { console.filter { $0.level == "error" }.count }

    init(file: URL, root: URL) {
        self.file = file
        self.root = root
        handler = SiteSchemeHandler(root: root)
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(handler, forURLScheme: SiteURL.scheme)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.websiteDataStore = .default()
        if let js = Bundle.main.url(forResource: "console", withExtension: "js").flatMap({ try? String(contentsOf: $0) }) {
            config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        }
        webView = WKWebView(frame: .zero, configuration: config)
        webView.isFindInteractionEnabled = true
        webView.isInspectable = true
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        super.init()
        config.userContentController.add(WeakScriptHandler(self), name: "viewerConsole")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        handler.onMissing = { [weak self] _ in self?.missingFiles = true }
        observations = [
            webView.observe(\.title) { [weak self] w, _ in Task { @MainActor in self?.title = w.title ?? "" } },
            webView.observe(\.estimatedProgress) { [weak self] w, _ in Task { @MainActor in self?.progress = w.estimatedProgress } },
            webView.observe(\.isLoading) { [weak self] w, _ in Task { @MainActor in self?.loading = w.isLoading } },
            webView.observe(\.canGoBack) { [weak self] w, _ in Task { @MainActor in self?.canGoBack = w.canGoBack } },
            webView.observe(\.canGoForward) { [weak self] w, _ in Task { @MainActor in self?.canGoForward = w.canGoForward } },
        ]
        load()
    }

    func load() {
        failed = nil
        webView.load(URLRequest(url: SiteURL.url(for: file, root: root)))
    }

    func reload() {
        console.removeAll()
        missingFiles = false
        if webView.url == nil { load() } else { webView.reload() }
    }

    func toggleDesktop() {
        desktop.toggle()
        webView.configuration.defaultWebpagePreferences.preferredContentMode = desktop ? .desktop : .mobile
        webView.customUserAgent = nil
        webView.reload()
    }

    func find() {
        webView.findInteraction?.presentFindNavigator(showingReplace: false)
    }

    func clearConsole() { console.removeAll() }

    /// Runs JavaScript typed into the console and logs the result.
    func evaluate(_ code: String) {
        console.append(ConsoleEntry(level: "input", message: code, time: Date()))
        webView.evaluateJavaScript(code) { [weak self] result, error in
            guard let self else { return }
            if let error = error as NSError? {
                let msg = (error.userInfo["WKJavaScriptExceptionMessage"] as? String) ?? error.localizedDescription
                self.console.append(ConsoleEntry(level: "error", message: msg, time: Date()))
            } else {
                self.console.append(ConsoleEntry(level: "result", message: Self.describe(result), time: Date()))
            }
        }
    }

    private static func describe(_ value: Any?) -> String {
        switch value {
        case nil: return "undefined"
        case let s as String: return "\"\(s)\""
        case let n as NSNumber: return n.stringValue
        case let o where JSONSerialization.isValidJSONObject(o):
            let data = (try? JSONSerialization.data(withJSONObject: o, options: [.prettyPrinted, .sortedKeys])) ?? Data()
            return String(data: data, encoding: .utf8) ?? "\(o)"
        case let other?: return "\(other)"
        }
    }

    func makePDF() async -> URL? {
        guard let data = try? await webView.pdf() else { return nil }
        let name = (title.isEmpty ? file.deletingPathExtension().lastPathComponent : title)
            .replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
        do { try data.write(to: url) } catch { return nil }
        return url
    }

    func print() {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo.printInfo()
        info.jobName = title.isEmpty ? file.lastPathComponent : title
        info.outputType = .general
        controller.printInfo = info
        controller.printFormatter = webView.viewPrintFormatter()
        controller.present(animated: true)
    }

    fileprivate func receive(_ body: Any) {
        guard let dict = body as? [String: Any], let level = dict["level"] as? String, let text = dict["text"] as? String else { return }
        if console.count > 2000 { console.removeFirst(500) }
        console.append(ConsoleEntry(level: level, message: text, time: Date()))
    }
}

extension WebModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .cancel }
        let mainFrame = action.targetFrame?.isMainFrame ?? true
        switch NavigationPolicy.decide(url: url, root: root, isMainFrame: mainFrame,
                                       userTapped: action.navigationType == .linkActivated) {
        case .allow: return .allow
        case .cancel: return .cancel
        case .openExternally:
            await UIApplication.shared.open(url)
            return .cancel
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { failed = error.localizedDescription }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        console.append(ConsoleEntry(level: "warn", message: "The page used too much memory and was reloaded.", time: Date()))
        webView.reload()
    }
}

extension WebModel: WKUIDelegate {
    /// window.open / target=_blank: open in place (or outside, by the same policy).
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url {
            switch NavigationPolicy.decide(url: url, root: root, isMainFrame: true,
                                           userTapped: action.navigationType == .linkActivated) {
            case .allow: webView.load(action.request)
            case .openExternally: UIApplication.shared.open(url)
            case .cancel: break
            }
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async {
        await withCheckedContinuation { c in
            let a = alert(message)
            a.addAction(UIAlertAction(title: "OK", style: .default) { _ in c.resume() })
            if !present(a) { c.resume() }
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async -> Bool {
        await withCheckedContinuation { c in
            let a = alert(message)
            a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in c.resume(returning: false) })
            a.addAction(UIAlertAction(title: "OK", style: .default) { _ in c.resume(returning: true) })
            if !present(a) { c.resume(returning: false) }
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo) async -> String? {
        await withCheckedContinuation { c in
            let a = alert(prompt)
            a.addTextField { $0.text = defaultText }
            a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in c.resume(returning: nil) })
            a.addAction(UIAlertAction(title: "OK", style: .default) { [weak a] _ in c.resume(returning: a?.textFields?.first?.text ?? "") })
            if !present(a) { c.resume(returning: nil) }
        }
    }

    private func alert(_ message: String) -> UIAlertController {
        UIAlertController(title: title.isEmpty ? nil : title, message: message, preferredStyle: .alert)
    }

    /// False when there's no window to show it in (the caller then answers for the page).
    private func present(_ alert: UIAlertController) -> Bool {
        var top = webView.window?.rootViewController
        while let next = top?.presentedViewController { top = next }
        guard let top else { return false }
        top.present(alert, animated: true)
        return true
    }
}

/// Avoids the retain cycle WKUserContentController creates with its message handlers.
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var model: WebModel?
    init(_ model: WebModel) { self.model = model }
    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        let body = message.body
        Task { @MainActor in self.model?.receive(body) }
    }
}
