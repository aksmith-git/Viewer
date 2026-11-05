import Foundation
import UniformTypeIdentifiers

/// Which viewer a file opens in.
enum FileKind: Equatable {
    case html, folder, zip, markdown, json
    case csv(separator: Character)
    case code(language: String)
    case text, quickLook, unknown

    static func classify(_ url: URL) -> FileKind {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true { return .folder }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "html", "htm", "xhtml", "shtml", "svg": return .html
        case "zip": return .zip
        case "md", "markdown", "mdown", "mkd": return .markdown
        case "json", "geojson", "jsonc", "webmanifest": return .json
        case "csv": return .csv(separator: ",")
        case "tsv", "tab": return .csv(separator: "\t")
        case "txt", "text": return .text
        default: break
        }
        if let lang = Languages.language(forExtension: ext) { return .code(language: lang) }
        if let type = UTType(filenameExtension: ext), quickLookTypes.contains(where: { type.conforms(to: $0) }) {
            return .quickLook
        }
        return sniff(url)
    }

    private static let quickLookTypes: [UTType] = {
        var t: [UTType] = [.pdf, .image, .audiovisualContent, .audio, .movie, .presentation, .spreadsheet, .rtf, .rtfd,
                           .usdz, .usd, .realityFile, .epub, .vCard, .calendarEvent]
        for id in ["org.openxmlformats.wordprocessingml.document", "com.microsoft.word.doc",
                   "org.openxmlformats.spreadsheetml.sheet", "com.microsoft.excel.xls",
                   "org.openxmlformats.presentationml.presentation", "com.microsoft.powerpoint.ppt",
                   "com.apple.iwork.pages.sec-pages", "com.apple.iwork.numbers.sec-numbers",
                   "com.apple.iwork.keynote.sec-keynote", "com.apple.pages.pages", "com.apple.numbers.numbers",
                   "com.apple.keynote.key", "org.oasis-open.opendocument.text"] {
            if let u = UTType(id) { t.append(u) }
        }
        return t
    }()

    /// No known extension: look at the first 4 KB.
    private static func sniff(_ url: URL) -> FileKind {
        guard let h = try? FileHandle(forReadingFrom: url) else { return .unknown }
        defer { try? h.close() }
        let data = (try? h.read(upToCount: 4096)) ?? Data()
        if data.isEmpty { return .text }
        guard let text = decode(data) else { return .unknown }
        let head = text.drop { $0 == "\u{FEFF}" || $0.isWhitespace }.prefix(15).lowercased()
        if head.hasPrefix("<!doctype html") || head.hasPrefix("<html") { return .html }
        let controls = text.unicodeScalars.filter { $0.value < 32 && !"\n\r\t\u{0C}".unicodeScalars.contains($0) }.count
        return controls * 100 <= text.unicodeScalars.count ? .text : .unknown
    }

    /// UTF-16 (with BOM) or UTF-8; a UTF-8 sequence cut off at the 4 KB boundary is tolerated.
    private static func decode(_ data: Data) -> String? {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) { return String(data: data, encoding: .utf16) }
        for cut in 0...3 where data.count > cut {
            if let s = String(data: data.dropLast(cut), encoding: .utf8) { return s }
        }
        return nil
    }
}
