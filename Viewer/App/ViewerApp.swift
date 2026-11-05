import SwiftUI

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
                .onAppear {
                    // `-open <path>` launch argument: used for screenshots and testing
                    if let path = UserDefaults.standard.string(forKey: "open"), opener.opened == nil {
                        opener.open(URL(fileURLWithPath: path))
                    }
                    #if DEBUG
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
