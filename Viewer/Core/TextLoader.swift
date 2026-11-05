import Foundation

/// Reads up to `limit` bytes of a text file and decodes it (UTF-8, UTF-16 with BOM, else Latin-1).
enum TextLoader {
    static func load(_ url: URL, limit: Int) throws -> (text: String, truncated: Bool) {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = try handle.read(upToCount: limit + 1) ?? Data()
        let truncated = data.count > limit
        if truncated { data = data.prefix(limit) }

        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            var d = data
            if truncated && d.count % 2 == 1 { d = d.dropLast() }
            if let s = String(data: d, encoding: .utf16) { return (s, truncated) }
        }
        var utf8 = data
        if utf8.starts(with: [0xEF, 0xBB, 0xBF]) { utf8 = utf8.dropFirst(3) }
        // a cut can land inside a multi-byte character: back off up to 3 bytes
        for cut in 0...(truncated ? 3 : 0) where utf8.count >= cut {
            if let s = String(data: utf8.dropLast(cut), encoding: .utf8) { return (s, truncated) }
        }
        return (String(data: data, encoding: .isoLatin1) ?? "", truncated)
    }
}
