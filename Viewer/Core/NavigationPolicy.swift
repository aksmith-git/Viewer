import Foundation

enum NavDecision: Equatable { case allow, openExternally, cancel }

/// What a page may navigate to. Local files stay inside the opened folder; leaving for the web
/// (or mail, phone…) goes to the system, so Viewer never acts as a web browser.
enum NavigationPolicy {
    /// `userTapped`: only a tap on a link may send the user out of the app (not redirects or scripts).
    static func decide(url: URL, root: URL, isMainFrame: Bool, userTapped: Bool = true) -> NavDecision {
        let external: NavDecision = userTapped && isMainFrame ? .openExternally : .cancel
        switch url.scheme?.lowercased() {
        case "file":
            return isInside(url, root) ? .allow : .cancel
        case SiteURL.scheme:
            return SiteURL.file(for: url, root: root) != nil ? .allow : .cancel
        case "http", "https":
            return isMainFrame ? external : .allow
        case "mailto", "tel", "sms", "facetime", "maps":
            return external
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

    /// Standardised, symlinks resolved, and without the /private prefix — which resolving only
    /// removes for paths that exist, so a missing file would otherwise look outside its folder.
    static func canonical(_ url: URL) -> String {
        var path = URL(fileURLWithPath: url.path).standardizedFileURL.resolvingSymlinksInPath().path
        for prefix in ["/private/var/", "/private/tmp/", "/private/etc/"] where path.hasPrefix(prefix) {
            path.removeFirst("/private".count)
        }
        if path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        return path
    }
}
