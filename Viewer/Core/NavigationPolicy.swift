import Foundation

enum NavDecision: Equatable { case allow, openExternally, cancel }

/// What a page may navigate to. Local files stay inside the opened folder; leaving for the web
/// (or mail, phone…) goes to the system, so Viewer never acts as a web browser.
enum NavigationPolicy {
    static func decide(url: URL, root: URL, isMainFrame: Bool) -> NavDecision {
        switch url.scheme?.lowercased() {
        case "file":
            return isInside(url, root) ? .allow : .cancel
        case SiteURL.scheme:
            return SiteURL.file(for: url, root: root) != nil ? .allow : .cancel
        case "http", "https":
            return isMainFrame ? .openExternally : .allow
        case "mailto", "tel", "sms", "facetime", "maps":
            return .openExternally
        case "about", "data", "blob":
            return .allow
        default:
            return .cancel
        }
    }

    static func isInside(_ url: URL, _ root: URL) -> Bool {
        let path = canonical(url)
        let base = canonical(root)
        return path == base || path.hasPrefix(base.hasSuffix("/") ? base : base + "/")
    }

    private static func canonical(_ url: URL) -> String {
        URL(fileURLWithPath: url.path).standardizedFileURL.resolvingSymlinksInPath().path
    }
}
