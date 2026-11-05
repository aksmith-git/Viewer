import Foundation
import WebKit

/// Serves files under the opened root for `viewer://local/…` requests, with byte ranges so
/// <video> and <audio> can seek.
final class SiteSchemeHandler: NSObject, WKURLSchemeHandler {
    private let root: URL
    private var active = Set<ObjectIdentifier>()     // main thread only
    private let queue = DispatchQueue(label: "viewer.site", qos: .userInitiated, attributes: .concurrent)
    /// Called (main thread) when a request inside the root fails to read — used for the
    /// "missing files" hint.
    var onMissing: ((URL) -> Void)?

    init(root: URL) { self.root = root }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        let id = ObjectIdentifier(task)
        active.insert(id)
        guard let url = task.request.url else { return finish(task, status: 400) }
        guard let file = SiteURL.file(for: url, root: root) else { return finish(task, status: 403) }
        let range = task.request.value(forHTTPHeaderField: "Range")
        queue.async { [weak self] in
            guard let self else { return }
            guard let handle = try? FileHandle(forReadingFrom: file),
                  let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize else {
                DispatchQueue.main.async {
                    self.onMissing?(file)
                    self.finish(task, status: 404)
                }
                return
            }
            defer { try? handle.close() }
            var start = 0, end = size - 1, status = 200
            if let range, let r = Self.parse(range: range, size: size) { (start, end, status) = (r.0, r.1, 206) }
            let length = max(0, end - start + 1)
            var headers = [
                "Content-Type": SiteURL.mimeType(for: file),
                "Content-Length": "\(length)",
                "Accept-Ranges": "bytes",
                "Cache-Control": "no-cache",
                "Access-Control-Allow-Origin": "*",
            ]
            if status == 206 { headers["Content-Range"] = "bytes \(start)-\(end)/\(size)" }
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            DispatchQueue.main.async { if self.active.contains(id) { task.didReceive(response) } }
            try? handle.seek(toOffset: UInt64(start))
            var remaining = length
            while remaining > 0 {
                let chunk = (try? handle.read(upToCount: min(remaining, 1 << 20))) ?? Data()
                if chunk.isEmpty { break }
                remaining -= chunk.count
                DispatchQueue.main.async { if self.active.contains(id) { task.didReceive(chunk) } }
            }
            DispatchQueue.main.async {
                if self.active.remove(id) != nil { task.didFinish() }
            }
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        active.remove(ObjectIdentifier(task))
    }

    private func finish(_ task: WKURLSchemeTask, status: Int) {
        guard active.remove(ObjectIdentifier(task)) != nil, let url = task.request.url else { return }
        let body = Data("\(status)".utf8)
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "text/plain", "Content-Length": "\(body.count)"])!
        task.didReceive(response)
        task.didReceive(body)
        task.didFinish()
    }

    /// "bytes=a-b", "bytes=a-", "bytes=-n" → inclusive (start, end).
    static func parse(range: String, size: Int) -> (Int, Int)? {
        guard size > 0, range.hasPrefix("bytes="), !range.contains(",") else { return nil }
        let parts = range.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        if parts[0].isEmpty, let n = Int(parts[1]) { return (max(0, size - n), size - 1) }
        guard let a = Int(parts[0]), a < size else { return nil }
        let b = Int(parts[1]).map { min($0, size - 1) } ?? size - 1
        return a <= b ? (a, b) : nil
    }
}
