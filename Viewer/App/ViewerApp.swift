import SwiftUI
import UniformTypeIdentifiers

@main
struct ViewerApp: App {
    @StateObject private var recents: RecentsStore
    @StateObject private var opener: OpenController

    init() {
        let store = RecentsStore.standard()
        _recents = StateObject(wrappedValue: store)
        _opener = StateObject(wrappedValue: OpenController(recents: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(recents)
                .environmentObject(opener)
                .onOpenURL { opener.open($0) }
                .onDrop(of: [.fileURL, .item], isTargeted: nil) { providers in
                    guard let provider = providers.first else { return false }
                    DropImporter.importFile(from: provider, into: opener.importedRoot) { url in
                        if let url { opener.open(url) }
                    }
                    return true
                }
                .onAppear {
                    #if DEBUG
                    // `-open <path>` launch argument: used for screenshots and testing
                    if let path = UserDefaults.standard.string(forKey: "open"), opener.opened == nil {
                        opener.open(URL(fileURLWithPath: path))
                    }
                    // Remote testing: a Documents/.open file naming a file in Documents opens it at launch.
                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let request = docs.appendingPathComponent(".open")
                    if let name = try? String(contentsOf: request).trimmingCharacters(in: .whitespacesAndNewlines) {
                        try? FileManager.default.removeItem(at: request)
                        opener.open(docs.appendingPathComponent(name))
                    }
                    #endif
                }
        }
    }
}

/// iPhone: one navigation stack (Home → document → files inside it).
/// iPad: recents in the sidebar, the open document in the detail column.
struct RootView: View {
    @EnvironmentObject private var opener: OpenController
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            NavigationSplitView {
                HomeView(selection: Binding(get: { opener.opened?.standardizedFileURL.path }, set: { _ in }))
            } detail: {
                NavigationStack(path: $opener.children) {
                    Group {
                        if let url = opener.opened {
                            DocumentView(url: url).id(url)
                        } else {
                            ContentUnavailableView("No File Open", systemImage: "doc.viewfinder",
                                                   description: Text("Choose a recent file, or tap Browse."))
                        }
                    }
                    .navigationDestination(for: URL.self) { DocumentView(url: $0) }
                }
            }
        } else {
            NavigationStack(path: compactPath) {
                HomeView()
                    .navigationDestination(for: URL.self) { DocumentView(url: $0) }
            }
        }
    }

    private var compactPath: Binding<[URL]> {
        Binding(
            get: { opener.opened.map { [$0] + opener.children } ?? [] },
            set: { path in
                if let first = path.first, first == opener.opened {
                    opener.children = Array(path.dropFirst())
                } else if path.isEmpty {
                    opener.close()
                }
            }
        )
    }
}

/// Files dragged in from other apps (iPad) are copied into Imported/<uuid>/ and opened.
enum DropImporter {
    static func importFile(from provider: NSItemProvider, into root: URL, completion: @escaping @MainActor (URL?) -> Void) {
        let type = provider.registeredTypeIdentifiers.first { UTType($0)?.conforms(to: .item) == true } ?? UTType.item.identifier
        provider.loadFileRepresentation(forTypeIdentifier: type) { temp, _ in
            var result: URL?
            if let temp {
                let dest = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
                let name = provider.suggestedName.map { n in temp.pathExtension.isEmpty || n.hasSuffix("." + temp.pathExtension) ? n : n + "." + temp.pathExtension }
                    ?? temp.lastPathComponent
                let target = dest.appendingPathComponent(name)
                do {
                    try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: temp, to: target)   // temp is deleted when this returns
                    result = target
                } catch {}
            }
            Task { @MainActor in completion(result) }
        }
    }
}
