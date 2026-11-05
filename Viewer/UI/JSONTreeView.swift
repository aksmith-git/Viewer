import SwiftUI

/// JSON as an outline: tap to expand, long-press to copy a value or its path.
struct JSONTreeView: View {
    let url: URL
    @State private var root: JSONNode?
    @State private var error: String?
    @State private var showSource = false
    static let treeLimit = 10 * 1024 * 1024

    var body: some View {
        Group {
            if showSource {
                CodeViewer(url: url, language: "json")
            } else if let root {
                List {
                    JSONRowGroup(key: nil, node: root, path: "$", expanded: true)
                }
                .listStyle(.plain)
                .font(.system(.callout, design: .monospaced))
            } else if let error {
                ContentUnavailableView {
                    Label("Invalid JSON", systemImage: "curlybraces")
                } description: {
                    Text(error)
                } actions: {
                    Button("View as Text") { showSource = true }
                }
            } else {
                ProgressView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $showSource) {
                    Text("Tree").tag(false)
                    Text("Text").tag(true)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .task(id: url) {
            let url = url
            do {
                root = try await Task.detached { try JSONNode.parse(try Data(contentsOf: url)) }.value
            } catch let e as JSONNode.ParseError {
                error = "Couldn't read this JSON: \(e.reason.lowercased()) at byte \(e.offset)."
            } catch {
                self.error = "Viewer couldn't read this file."
            }
        }
    }
}

private struct JSONRowGroup: View {
    let key: String?
    let node: JSONNode
    let path: String
    @State var expanded: Bool

    var body: some View {
        switch node {
        case .object(let pairs):
            DisclosureGroup(isExpanded: $expanded) {
                if expanded {
                    ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                        JSONRowGroup(key: pair.0, node: pair.1, path: path + Self.member(pair.0), expanded: false)
                    }
                }
            } label: { label }
        case .array(let items):
            DisclosureGroup(isExpanded: $expanded) {
                if expanded {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        JSONRowGroup(key: "\(i)", node: item, path: path + "[\(i)]", expanded: false)
                    }
                }
            } label: { label }
        default:
            label
        }
    }

    private var label: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let key {
                Text(key).foregroundStyle(.purple).fontWeight(.medium)
                Text(":").foregroundStyle(.secondary)
            }
            value
                .lineLimit(node.childCount > 0 ? 1 : 3)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button { UIPasteboard.general.string = node.text(pretty: true) } label: { Label("Copy Value", systemImage: "doc.on.doc") }
            Button { UIPasteboard.general.string = path } label: { Label("Copy Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
            if let key { Button { UIPasteboard.general.string = key } label: { Label("Copy Key", systemImage: "key") } }
        }
    }

    @ViewBuilder private var value: some View {
        switch node {
        case .object(let p): Text(p.isEmpty ? "{ }" : "{ \(p.count) \(p.count == 1 ? "key" : "keys") }").foregroundStyle(.secondary)
        case .array(let a): Text(a.isEmpty ? "[ ]" : "[ \(a.count) \(a.count == 1 ? "item" : "items") ]").foregroundStyle(.secondary)
        case .string(let s): Text("\"\(s)\"").foregroundStyle(Self.stringColor)
        case .number(let n): Text(n).foregroundStyle(.blue)
        case .bool(let b): Text(b ? "true" : "false").foregroundStyle(.orange)
        case .null: Text("null").foregroundStyle(.secondary).italic()
        }
    }

    /// Dark red on light, soft coral on dark (both above 4.5:1).
    static let stringColor = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 1.0, green: 0.52, blue: 0.47, alpha: 1)
        : UIColor(red: 0.70, green: 0.10, blue: 0.08, alpha: 1) })

    private static func member(_ key: String) -> String {
        let simple = key.range(of: #"^[A-Za-z_$][A-Za-z0-9_$]*$"#, options: .regularExpression) != nil
        return simple ? ".\(key)" : "[\"\(key.replacingOccurrences(of: "\"", with: "\\\""))\"]"
    }
}

extension JSONNode {
    /// Back to JSON text (numbers as written, key order kept).
    func text(pretty: Bool, indent: String = "") -> String {
        let step = pretty ? "  " : ""
        let nl = pretty ? "\n" : ""
        switch self {
        case .object(let pairs):
            if pairs.isEmpty { return "{}" }
            let inner = pairs.map { "\(indent)\(step)\(Self.quote($0.0)):\(pretty ? " " : "")\($0.1.text(pretty: pretty, indent: indent + step))" }
            return "{\(nl)\(inner.joined(separator: ",\(nl)"))\(nl)\(indent)}"
        case .array(let items):
            if items.isEmpty { return "[]" }
            let inner = items.map { "\(indent)\(step)\($0.text(pretty: pretty, indent: indent + step))" }
            return "[\(nl)\(inner.joined(separator: ",\(nl)"))\(nl)\(indent)]"
        case .string(let s): return Self.quote(s)
        case .number(let n): return n
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        }
    }

    private static func quote(_ s: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [s], options: [.withoutEscapingSlashes])) ?? Data()
        let array = String(data: data, encoding: .utf8) ?? "[\"\"]"
        return String(array.dropFirst().dropLast())
    }
}
