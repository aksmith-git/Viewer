import SwiftUI
import UniformTypeIdentifiers

/// For files Viewer has no viewer for: what it is, and a way to try it as text.
struct InfoView: View {
    let url: URL
    @State private var asText = false

    var body: some View {
        if asText {
            CodeViewer(url: url, language: nil)
        } else {
            List {
                Section {
                    VStack(spacing: 10) {
                        KindBadge(style: KindStyle(url: url), size: 72)
                        Text(url.lastPathComponent)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text("Viewer can't preview this kind of file.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }
                Section("Information") {
                    LabeledContent("Kind", value: kind)
                    LabeledContent("Size", value: size)
                    if let created = values?.creationDate { LabeledContent("Created", value: created.formatted(date: .abbreviated, time: .shortened)) }
                    if let modified = values?.contentModificationDate { LabeledContent("Modified", value: modified.formatted(date: .abbreviated, time: .shortened)) }
                    LabeledContent("Where", value: url.deletingLastPathComponent().lastPathComponent)
                }
                Section {
                    Button { asText = true } label: { Label("Open as Text", systemImage: "doc.plaintext") }
                }
            }
        }
    }

    private var values: URLResourceValues? {
        try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
    }

    private var size: String {
        ByteCountFormatter.string(fromByteCount: Int64(values?.fileSize ?? 0), countStyle: .file)
    }

    private var kind: String {
        let ext = url.pathExtension
        if let type = UTType(filenameExtension: ext), let d = type.localizedDescription, !type.isDynamic { return d }
        return ext.isEmpty ? "File" : "\(ext.uppercased()) file"
    }
}
