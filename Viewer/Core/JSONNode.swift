import Foundation

/// A parsed JSON value that keeps object key order and numbers exactly as written
/// (Foundation's JSONSerialization keeps neither).
indirect enum JSONNode {
    case object([(String, JSONNode)])
    case array([JSONNode])
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    struct ParseError: Error, CustomStringConvertible {
        let offset: Int
        let reason: String
        var description: String { "\(reason) at byte \(offset)" }
    }

    static func parse(_ data: Data) throws -> JSONNode {
        var p = Parser(bytes: [UInt8](data))
        p.skipBOM()
        let value = try p.value(depth: 0)
        p.skipWhitespace()
        guard p.i == p.bytes.count else { throw ParseError(offset: p.i, reason: "Unexpected text after the end") }
        return value
    }

    var childCount: Int {
        switch self {
        case .object(let o): return o.count
        case .array(let a): return a.count
        default: return 0
        }
    }

    private struct Parser {
        let bytes: [UInt8]
        var i = 0
        static let maxDepth = 512

        mutating func skipBOM() { if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { i = 3 } }

        mutating func skipWhitespace() {
            while i < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[i]) { i += 1 }
        }

        func fail(_ reason: String) -> ParseError { ParseError(offset: i, reason: reason) }

        mutating func value(depth: Int) throws -> JSONNode {
            guard depth < Self.maxDepth else { throw fail("Nested too deeply") }
            skipWhitespace()
            guard i < bytes.count else { throw fail("Unexpected end") }
            switch bytes[i] {
            case UInt8(ascii: "{"): return try object(depth: depth)
            case UInt8(ascii: "["): return try array(depth: depth)
            case UInt8(ascii: "\""): return .string(try string())
            case UInt8(ascii: "t"): try literal("true"); return .bool(true)
            case UInt8(ascii: "f"): try literal("false"); return .bool(false)
            case UInt8(ascii: "n"): try literal("null"); return .null
            case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"): return .number(try number())
            default: throw fail("Unexpected character")
            }
        }

        mutating func literal(_ word: String) throws {
            let w = Array(word.utf8)
            guard i + w.count <= bytes.count, Array(bytes[i..<i + w.count]) == w else { throw fail("Expected \(word)") }
            i += w.count
        }

        mutating func object(depth: Int) throws -> JSONNode {
            i += 1
            var pairs: [(String, JSONNode)] = []
            skipWhitespace()
            if i < bytes.count, bytes[i] == UInt8(ascii: "}") { i += 1; return .object(pairs) }
            while true {
                skipWhitespace()
                guard i < bytes.count, bytes[i] == UInt8(ascii: "\"") else { throw fail("Expected a key") }
                let key = try string()
                skipWhitespace()
                guard i < bytes.count, bytes[i] == UInt8(ascii: ":") else { throw fail("Expected :") }
                i += 1
                pairs.append((key, try value(depth: depth + 1)))
                skipWhitespace()
                guard i < bytes.count else { throw fail("Unexpected end") }
                if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
                if bytes[i] == UInt8(ascii: "}") { i += 1; return .object(pairs) }
                throw fail("Expected , or }")
            }
        }

        mutating func array(depth: Int) throws -> JSONNode {
            i += 1
            var items: [JSONNode] = []
            skipWhitespace()
            if i < bytes.count, bytes[i] == UInt8(ascii: "]") { i += 1; return .array(items) }
            while true {
                items.append(try value(depth: depth + 1))
                skipWhitespace()
                guard i < bytes.count else { throw fail("Unexpected end") }
                if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
                if bytes[i] == UInt8(ascii: "]") { i += 1; return .array(items) }
                throw fail("Expected , or ]")
            }
        }

        mutating func number() throws -> String {
            let start = i
            if bytes[i] == UInt8(ascii: "-") { i += 1 }
            let allowed = Set("0123456789.eE+-".utf8)
            while i < bytes.count, allowed.contains(bytes[i]) { i += 1 }
            let s = String(decoding: bytes[start..<i], as: UTF8.self)
            guard Double(s) != nil else { throw ParseError(offset: start, reason: "Bad number") }
            return s
        }

        mutating func string() throws -> String {
            i += 1
            var out = [UInt8]()
            while i < bytes.count {
                let b = bytes[i]
                if b == UInt8(ascii: "\"") { i += 1; return String(decoding: out, as: UTF8.self) }
                if b == UInt8(ascii: "\\") {
                    i += 1
                    guard i < bytes.count else { break }
                    switch bytes[i] {
                    case UInt8(ascii: "n"): out.append(0x0A)
                    case UInt8(ascii: "t"): out.append(0x09)
                    case UInt8(ascii: "r"): out.append(0x0D)
                    case UInt8(ascii: "b"): out.append(0x08)
                    case UInt8(ascii: "f"): out.append(0x0C)
                    case UInt8(ascii: "u"):
                        var scalar = try hex4()
                        if (0xD800...0xDBFF).contains(scalar), i + 2 < bytes.count,
                           bytes[i + 1] == UInt8(ascii: "\\"), bytes[i + 2] == UInt8(ascii: "u") {
                            i += 2
                            let low = try hex4()
                            scalar = 0x10000 + ((scalar - 0xD800) << 10) + (low - 0xDC00)
                        }
                        out.append(contentsOf: Array(String(Unicode.Scalar(scalar).map(Character.init) ?? "\u{FFFD}").utf8))
                    default: out.append(bytes[i])        // \" \\ \/
                    }
                    i += 1
                } else {
                    out.append(b)
                    i += 1
                }
            }
            throw fail("Unterminated string")
        }

        /// Reads the 4 hex digits after "\u"; leaves `i` on the last digit.
        mutating func hex4() throws -> UInt32 {
            guard i + 4 < bytes.count, let v = UInt32(String(decoding: bytes[(i + 1)...(i + 4)], as: UTF8.self), radix: 16)
            else { throw fail("Bad \\u escape") }
            i += 4
            return v
        }
    }
}
