import CryptoKit
import Foundation
import ZIPFoundation

enum ZipError: Error, Equatable {
    case unsafePath(String)
    case unreadable
}

/// Unpacks a zip into Caches/Extracted/<hash>/ so its pages can load their CSS, JS and images.
enum ZipExtractor {
    static func extract(_ zip: URL, cachesRoot: URL) throws -> URL {
        let extracted = cachesRoot.appendingPathComponent("Extracted", isDirectory: true)
        let final = extracted.appendingPathComponent(try key(for: zip), isDirectory: true)
        let fm = FileManager.default
        if !fm.fileExists(atPath: final.path) {
            let staging = extracted.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
            do {
                try unpack(zip, into: staging)
                try fm.moveItem(at: staging, to: final)
            } catch {
                try? fm.removeItem(at: staging)
                throw error
            }
        }
        return unwrapSingleFolder(final)
    }

    /// Same zip (path, size, date) → same folder, so reopening is instant.
    private static func key(for zip: URL) throws -> String {
        let v = try zip.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let id = "\(zip.standardizedFileURL.path)|\(v.fileSize ?? 0)|\(v.contentModificationDate?.timeIntervalSince1970 ?? 0)"
        return SHA256.hash(data: Data(id.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private static func unpack(_ zip: URL, into root: URL) throws {
        let archive: Archive
        do { archive = try Archive(url: zip, accessMode: .read) } catch { throw ZipError.unreadable }
        let rootPath = root.standardizedFileURL.path
        for entry in archive {
            let path = entry.path
            if path.hasPrefix("__MACOSX/") || path.hasSuffix("/.DS_Store") || path == ".DS_Store" { continue }
            let dest = root.appendingPathComponent(path).standardizedFileURL
            guard dest.path.hasPrefix(rootPath + "/"), !path.hasPrefix("/") else { throw ZipError.unsafePath(path) }
            switch entry.type {
            case .directory:
                try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            case .file:
                try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                _ = try archive.extract(entry, to: dest, skipCRC32: false)
            case .symlink:
                continue   // never follow links out of the folder
            }
        }
    }

    /// A zip made by compressing one folder holds just that folder: show its contents directly.
    private static func unwrapSingleFolder(_ root: URL) -> URL {
        let items = ((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? [])
            .filter { !$0.lastPathComponent.hasPrefix(".") }
        if items.count == 1, (try? items[0].resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            return items[0]
        }
        return root
    }
}
