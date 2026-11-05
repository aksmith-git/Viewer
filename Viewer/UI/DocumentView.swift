import SwiftUI

/// Shows one file or folder. (Routing to the real viewers comes in later tasks.)
struct DocumentView: View {
    let url: URL

    var body: some View {
        let style = KindStyle(url: url)
        VStack(spacing: 12) {
            KindBadge(style: style, size: 64)
            Text(url.lastPathComponent).font(.headline)
            Text(style.label).foregroundStyle(.secondary)
        }
        .navigationTitle(url.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
    }
}
