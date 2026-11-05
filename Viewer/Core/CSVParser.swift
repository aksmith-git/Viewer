import Foundation

/// RFC 4180 CSV/TSV: quoted fields, "" escapes, newlines inside quotes, CRLF or LF.
enum CSVParser {
    static func parse(_ text: String, separator: Character, maxRows: Int) -> (rows: [[String]], truncated: Bool) {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var chars = text.makeIterator()
        var pending: Character? = nil

        func endRow() {
            row.append(field)
            field = ""
            rows.append(row)
            row = []
        }

        while let c = pending ?? chars.next() {
            pending = nil
            if quoted {
                if c == "\"" {
                    if let next = chars.next() {
                        if next == "\"" { field.append("\"") } else { quoted = false; pending = next }
                    } else {
                        quoted = false
                    }
                } else {
                    field.append(c)
                }
                continue
            }
            switch c {
            case "\"" where field.isEmpty:
                quoted = true
            case separator:
                row.append(field)
                field = ""
            case "\r\n", "\n", "\r":                  // Swift treats CRLF as one Character
                endRow()
                if rows.count == maxRows {
                    let more = chars.next() != nil
                    return (rows, more)
                }
            default:
                field.append(c)
            }
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return (rows, false)
    }
}
