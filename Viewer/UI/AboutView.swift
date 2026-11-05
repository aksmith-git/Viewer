import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image("AboutIcon")
                            .resizable()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                            .accessibilityHidden(true)
                        Text("Viewer").font(.title.bold())
                        Text(version).font(.footnote).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .listRowBackground(Color.clear)
                }

                Section("Opens") {
                    Feature(symbol: "globe", tint: .orange, title: "Web pages", detail: "HTML with JavaScript, CSS and modules — whole folders and zips too")
                    Feature(symbol: "doc.richtext", tint: .red, title: "Documents", detail: "PDF, Word, Excel, PowerPoint, Pages, Numbers, Keynote, RTF")
                    Feature(symbol: "chevron.left.forwardslash.chevron.right", tint: .purple, title: "Code", detail: "Syntax colours for nearly 200 languages")
                    Feature(symbol: "text.badge.star", tint: .indigo, title: "Markdown, JSON and CSV", detail: "Rendered, as a tree, and as a table")
                    Feature(symbol: "photo.on.rectangle", tint: .cyan, title: "Media", detail: "Images, video, audio and 3D models")
                }

                Section {
                    Label {
                        Text("Viewer works entirely on your device. It has no accounts, no tracking and collects no data.")
                    } icon: {
                        Image(systemName: "hand.raised.fill").foregroundStyle(.blue)
                    }
                } header: { Text("Privacy") }

                Section("Acknowledgements") {
                    ForEach([("highlight.js", "highlight.js"), ("marked", "marked"), ("ZIPFoundation", "ZIPFoundation")], id: \.0) { name, file in
                        NavigationLink(name) { LicenseView(name: name, file: file) }
                    }
                }

                Section {
                    Link(destination: URL(string: "https://aksmith-git.github.io/Viewer/")!) {
                        Label("Support", systemImage: "questionmark.circle")
                    }
                    Link(destination: URL(string: "https://aksmith-git.github.io/Viewer/privacy.html")!) {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct Feature: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct LicenseView: View {
    let name: String
    let file: String

    var body: some View {
        ScrollView {
            Text(Bundle.main.url(forResource: file, withExtension: "txt").flatMap { try? String(contentsOf: $0) } ?? "")
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
