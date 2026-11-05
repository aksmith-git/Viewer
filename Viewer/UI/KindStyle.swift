import SwiftUI
import UniformTypeIdentifiers

/// Icon, tint and label for a file, used in lists and headers.
struct KindStyle {
    let symbol: String
    let tint: Color
    let label: String

    init(url: URL) {
        let kind = FileKind.classify(url)
        let ext = url.pathExtension.lowercased()
        let type = UTType(filenameExtension: ext)
        switch kind {
        case .html:
            if ext == "svg" { (symbol, tint, label) = ("square.on.circle", .pink, "SVG") }
            else { (symbol, tint, label) = ("globe", .orange, "Web Page") }
        case .folder: (symbol, tint, label) = ("folder.fill", .blue, "Folder")
        case .zip: (symbol, tint, label) = ("doc.zipper", .brown, "Zip Archive")
        case .markdown: (symbol, tint, label) = ("text.badge.star", .indigo, "Markdown")
        case .json: (symbol, tint, label) = ("curlybraces", .teal, "JSON")
        case .csv: (symbol, tint, label) = ("tablecells", .green, ext == "csv" ? "CSV" : "TSV")
        case .code(let lang): (symbol, tint, label) = ("chevron.left.forwardslash.chevron.right", .purple, Self.languageName(lang, ext: ext))
        case .text: (symbol, tint, label) = ("doc.plaintext", .gray, "Text")
        case .unknown: (symbol, tint, label) = ("doc", .gray, "File")
        case .quickLook:
            if type?.conforms(to: .pdf) == true { (symbol, tint, label) = ("doc.richtext", .red, "PDF") }
            else if type?.conforms(to: .image) == true { (symbol, tint, label) = ("photo", .cyan, "Image") }
            else if type?.conforms(to: .movie) == true || type?.conforms(to: .video) == true { (symbol, tint, label) = ("film", .mint, "Video") }
            else if type?.conforms(to: .audio) == true { (symbol, tint, label) = ("waveform", .pink, "Audio") }
            else if type?.conforms(to: .presentation) == true { (symbol, tint, label) = ("play.rectangle", .orange, "Presentation") }
            else if type?.conforms(to: .spreadsheet) == true { (symbol, tint, label) = ("tablecells.fill", .green, "Spreadsheet") }
            else if type?.conforms(to: .threeDContent) == true { (symbol, tint, label) = ("cube", .yellow, "3D Model") }
            else { (symbol, tint, label) = ("doc.text", .blue, type?.localizedDescription ?? "Document") }
        }
    }

    private static func languageName(_ lang: String, ext: String) -> String {
        let names = ["javascript": "JavaScript", "typescript": "TypeScript", "objectivec": "Objective-C", "cpp": "C++",
                     "csharp": "C#", "css": "CSS", "xml": "XML", "yaml": "YAML", "sql": "SQL", "php": "PHP",
                     "bash": "Shell Script", "plaintext": "Text", "ini": "Config", "fsharp": "F#", "x86asm": "Assembly",
                     "latex": "LaTeX", "graphql": "GraphQL", "glsl": "GLSL", "scss": "SCSS", "vbnet": "VB.NET"]
        return names[lang] ?? lang.prefix(1).uppercased() + lang.dropFirst()
    }
}

/// The rounded, tinted icon used in rows.
struct KindBadge: View {
    let style: KindStyle
    var size: CGFloat = 34

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(style.tint.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: style.symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .accessibilityHidden(true)
    }
}
