import SwiftUI
import WebKit

/// HTML with JavaScript, plus the power tools.
struct WebViewer: View {
    @StateObject private var model: WebModel
    @State private var showConsole = false
    @State private var showSource = false
    @State private var pdf: URL?
    @State private var makingPDF = false
    @State private var hintDismissed = false

    init(file: URL, root: URL) {
        _model = StateObject(wrappedValue: WebModel(file: file, root: root))
    }

    var body: some View {
        WebViewHost(webView: model.webView)
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                if model.loading && model.progress < 1 {
                    ProgressView(value: model.progress).progressViewStyle(.linear).tint(.accentColor)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if model.missingFiles && !hintDismissed { missingHint.padding().transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            .overlay {
                if let failed = model.failed {
                    ContentUnavailableView {
                        Label("Couldn't Open Page", systemImage: "exclamationmark.triangle")
                    } description: { Text(failed) } actions: { Button("Try Again") { model.load() } }
                    .background(.background)
                }
            }
            .animation(.snappy, value: model.missingFiles)
            .animation(.easeOut, value: model.loading)
            .navigationTitle(model.title.isEmpty ? model.file.lastPathComponent : model.title)
            .toolbar { toolbar }
            .sheet(isPresented: $showConsole) { ConsoleView(model: model) }
            .sheet(isPresented: $showSource) {
                NavigationStack { SourceView(url: model.file) }
            }
            .sheet(item: $pdf) { ShareSheet(items: [$0]).ignoresSafeArea() }
            .task {
                // `-showConsole YES` launch argument, for screenshots
                if UserDefaults.standard.bool(forKey: "showConsole") {
                    try? await Task.sleep(for: .seconds(1.5))
                    showConsole = true
                }
            }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if model.canGoBack || model.canGoForward {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { model.webView.goBack() } label: { Label("Back", systemImage: "chevron.backward") }
                    .disabled(!model.canGoBack)
                Button { model.webView.goForward() } label: { Label("Forward", systemImage: "chevron.forward") }
                    .disabled(!model.canGoForward)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if !model.console.isEmpty {
                Button { showConsole = true } label: {
                    Label("Console", systemImage: model.errorCount > 0 ? "exclamationmark.bubble.fill" : "terminal")
                }
                .tint(model.errorCount > 0 ? .red : nil)
                .accessibilityValue(model.errorCount > 0 ? "\(model.errorCount) errors" : "")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section {
                    Button { model.find() } label: { Label("Find on Page", systemImage: "magnifyingglass") }
                    Button { showSource = true } label: { Label("View Source", systemImage: "chevron.left.forwardslash.chevron.right") }
                    Button { showConsole = true } label: {
                        Label(model.errorCount > 0 ? "Console (\(model.errorCount) errors)" : "Console", systemImage: "terminal")
                    }
                }
                Section {
                    Button { model.toggleDesktop() } label: {
                        model.desktop ? Label("Request Mobile Site", systemImage: "iphone") : Label("Request Desktop Site", systemImage: "desktopcomputer")
                    }
                    Button { model.reload() } label: { Label("Reload", systemImage: "arrow.clockwise") }
                }
                Section {
                    Button {
                        makingPDF = true
                        Task { pdf = await model.makePDF(); makingPDF = false }
                    } label: { Label("Save as PDF", systemImage: "doc.richtext") }
                    Button { model.print() } label: { Label("Print", systemImage: "printer") }
                }
            } label: {
                if makingPDF { ProgressView() } else { Label("More", systemImage: "ellipsis") }
            }
        }
    }

    private var missingHint: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled").font(.title3).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Some files couldn't load").font(.subheadline.weight(.semibold))
                Text("Images, styles or scripts next to this page aren't available. Open the whole folder or a zip of it to include them.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button { hintDismissed = true } label: {
                Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.secondary).padding(6)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// Source of a page (Task 5 swaps in syntax colouring).
struct SourceView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Text((try? String(contentsOf: url)) ?? "")
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .padding()
        }
        .navigationTitle(url.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}
