import CryptoKit
import Foundation
import UniformTypeIdentifiers

/// Pages are served from `viewer://local/<path inside the opened folder>` rather than `file://`,
/// so ES modules, fetch() and XHR of local files work as they do on a real web server.
enum SiteURL {
    static let scheme = "viewer"

    /// Each opened folder gets its own host, so sites can't read each other's storage.
    static func host(for root: URL) -> String {
        let digest = SHA256.hash(data: Data(NavigationPolicy.canonical(root).utf8))
        return "s" + digest.prefix(6).map { String(format: "%02x", $0) }.joined()
    }

    static func url(for file: URL, root: URL) -> URL {
        let base = root.standardizedFileURL.path
        var rel = String(file.standardizedFileURL.path.dropFirst(base.count))
        if rel.hasPrefix("/") { rel.removeFirst() }
        let encoded = rel.addingPercentEncoding(withAllowedCharacters: pathAllowed) ?? rel
        return URL(string: "\(scheme)://\(host(for: root))/\(encoded)")!
    }

    /// The file a site URL points to, or nil if it's not a site URL or would leave the root.
    static func file(for url: URL, root: URL) -> URL? {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == host(for: root) else { return nil }
        var path = url.path                      // percent-decoded, no query/fragment
        if path.hasPrefix("/") { path.removeFirst() }
        var file = root.appendingPathComponent(path).standardizedFileURL
        if url.hasDirectoryPath || path.isEmpty { file.appendPathComponent("index.html") }
        guard NavigationPolicy.isInside(file, root) else { return nil }
        return file
    }

    static func mimeType(for file: URL) -> String {
        let ext = file.pathExtension.lowercased()
        if let known = table[ext] { return known }
        return UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
    }

    private static let table: [String: String] = [
        "html": "text/html", "htm": "text/html", "xhtml": "application/xhtml+xml", "shtml": "text/html",
        "js": "text/javascript", "mjs": "text/javascript", "cjs": "text/javascript", "css": "text/css",
        "json": "application/json", "map": "application/json", "webmanifest": "application/manifest+json",
        "svg": "image/svg+xml", "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif",
        "webp": "image/webp", "avif": "image/avif", "ico": "image/x-icon", "wasm": "application/wasm",
        "woff": "font/woff", "woff2": "font/woff2", "ttf": "font/ttf", "otf": "font/otf",
        "mp4": "video/mp4", "m4v": "video/mp4", "webm": "video/webm", "mov": "video/quicktime",
        "mp3": "audio/mpeg", "m4a": "audio/mp4", "wav": "audio/wav", "ogg": "audio/ogg",
        "txt": "text/plain", "xml": "application/xml", "csv": "text/csv", "md": "text/markdown", "pdf": "application/pdf",
    ]

    private static let pathAllowed: CharacterSet = {
        var s = CharacterSet.urlPathAllowed
        s.remove(charactersIn: "#?;")
        return s
    }()
}
