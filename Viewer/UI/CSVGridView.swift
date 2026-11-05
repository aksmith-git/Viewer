import SwiftUI

/// CSV/TSV as a table: header row pinned, row numbers, scroll both ways.
struct CSVGridView: View {
    let url: URL
    let separator: Character
    @State private var table: Table?
    @State private var failed = false
    @State private var showSource = false
    @AppStorage("csvHeader") private var firstRowIsHeader = true
    static let maxRows = 50_000

    struct Table {
        let rows: [[String]]
        let truncated: Bool
        let widths: [CGFloat]
        let numeric: [Bool]
    }

    var body: some View {
        Group {
            if showSource {
                CodeViewer(url: url, language: nil)
            } else if let table {
                grid(table)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if table.truncated { NoticeBar(text: "Showing the first \(table.rows.count.formatted()) rows") }
                    }
            } else if failed {
                ContentUnavailableView("Can't Read Table", systemImage: "tablecells", description: Text("Viewer couldn't read this file as text."))
            } else {
                ProgressView("Reading table…")
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $showSource) {
                    Text("Table").tag(false)
                    Text("Text").tag(true)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle(isOn: $firstRowIsHeader) { Label("First Row Is Header", systemImage: "rectangle.topthird.inset.filled") }
                } label: { Label("Options", systemImage: "ellipsis") }
            }
        }
        .task(id: url) { await load() }
    }

    static let byteLimit = 32 * 1024 * 1024

    private func load() async {
        let url = url, sep = separator
        let result = await Task.detached { Self.loadTable(url, separator: sep, byteLimit: Self.byteLimit, maxRows: Self.maxRows) }.value
        if let result { table = result } else { failed = true }
    }

    /// Reads at most `byteLimit` bytes (dropping a partial last line) and up to `maxRows` rows.
    nonisolated static func loadTable(_ url: URL, separator: Character, byteLimit: Int, maxRows: Int) -> Table? {
        guard let loaded = try? TextLoader.load(url, limit: byteLimit) else { return nil }
        var text = loaded.text
        if loaded.truncated, let lastBreak = text.lastIndex(where: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }) {
            text = String(text[..<lastBreak])
        }
        let parsed = CSVParser.parse(text, separator: separator, maxRows: maxRows)
        return Table(rows: parsed.rows, truncated: parsed.truncated || loaded.truncated,
                     widths: widths(parsed.rows), numeric: numeric(parsed.rows))
    }

    private func grid(_ t: Table) -> some View {
        let header = firstRowIsHeader ? t.rows.first : nil
        let body = Array(firstRowIsHeader ? t.rows.dropFirst() : t.rows[...])
        let numberWidth = CGFloat(String(body.count).count) * 9 + 20
        return ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(body.indices, id: \.self) { i in
                        HStack(spacing: 0) {
                            Text("\(i + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .frame(width: numberWidth, alignment: .trailing)
                                .padding(.trailing, 8)
                            ForEach(t.widths.indices, id: \.self) { c in
                                cell(c < body[i].count ? body[i][c] : "", width: t.widths[c], trailing: t.numeric[c])
                            }
                        }
                        .background(i.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.035))
                    }
                } header: {
                    if let header {
                        HStack(spacing: 0) {
                            Color.clear.frame(width: numberWidth + 8, height: 1)
                            ForEach(t.widths.indices, id: \.self) { c in
                                Text(c < header.count ? header[c] : "")
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 9)
                                    .frame(width: t.widths[c], alignment: t.numeric[c] ? .trailing : .leading)
                            }
                        }
                        .background(.bar)
                        .overlay(alignment: .bottom) { Divider() }
                    }
                }
            }
            .padding(.bottom, 30)
        }
    }

    private func cell(_ value: String, width: CGFloat, trailing: Bool) -> some View {
        Text(value)
            .font(.subheadline)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: width, alignment: trailing ? .trailing : .leading)
            .contextMenu {
                Button { UIPasteboard.general.string = value } label: { Label("Copy", systemImage: "doc.on.doc") }
            } preview: {
                Text(value).padding().frame(maxWidth: 360)
            }
    }

    /// A column is numeric when most of its non-empty values (after the first row) are numbers.
    nonisolated static func numeric(_ rows: [[String]]) -> [Bool] {
        let sample = rows.dropFirst().prefix(300)
        let columns = rows.prefix(300).map(\.count).max() ?? 0
        return (0..<columns).map { c in
            let values = sample.compactMap { c < $0.count && !$0[c].isEmpty ? $0[c] : nil }
            guard !values.isEmpty else { return false }
            let numbers = values.filter { Double($0.replacingOccurrences(of: ",", with: "")) != nil }.count
            return numbers * 10 >= values.count * 8
        }
    }

    /// Column widths from the first 300 rows: wide enough for typical content, capped.
    nonisolated static func widths(_ rows: [[String]]) -> [CGFloat] {
        let columns = rows.prefix(300).map(\.count).max() ?? 0
        return (0..<columns).map { c in
            let longest = rows.prefix(300).map { c < $0.count ? $0[c].count : 0 }.max() ?? 0
            return min(max(CGFloat(longest) * 8.2 + 24, 64), 300)
        }
    }
}
