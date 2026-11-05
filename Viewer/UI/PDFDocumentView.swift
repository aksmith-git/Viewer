import PDFKit
import SwiftUI

/// Native PDF: continuous scroll, pinch zoom, page thumbnails, search, page indicator.
struct PDFDocumentView: View {
    let url: URL
    @State private var document: PDFDocument?
    @State private var page = 1
    @State private var showThumbnails = false
    @State private var locked = false
    @State private var password = ""
    @State private var wrongPassword = false
    @State private var pdfView = PDFView()

    var body: some View {
        Group {
            if locked {
                unlockView
            } else if document != nil {
                PDFKitHost(view: pdfView, page: $page)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .bottom) { pageIndicator }
                    .overlay(alignment: .trailing) {
                        if showThumbnails { ThumbnailStrip(view: pdfView).transition(.move(edge: .trailing)) }
                    }
                    .animation(.snappy, value: showThumbnails)
            } else {
                ContentUnavailableView("Can't Open PDF", systemImage: "doc.richtext", description: Text("The file may be damaged."))
            }
        }
        .toolbar {
            if document != nil && !locked {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { pdfView.findInteraction.presentFindNavigator(showingReplace: false) } label: { Label("Find", systemImage: "magnifyingglass") }
                        Button { showThumbnails.toggle() } label: {
                            Label(showThumbnails ? "Hide Pages" : "Show Pages", systemImage: "rectangle.portrait.on.rectangle.portrait")
                        }
                        Button {
                            pdfView.displayMode = pdfView.displayMode == .singlePageContinuous ? .twoUpContinuous : .singlePageContinuous
                        } label: { Label("Two Pages Side by Side", systemImage: "book") }
                    } label: { Label("Options", systemImage: "ellipsis") }
                }
            }
        }
        .task(id: url) { load() }
    }

    private func load() {
        guard let doc = PDFDocument(url: url) else { document = nil; return }
        document = doc
        locked = doc.isLocked
        configure(doc)
    }

    private func configure(_ doc: PDFDocument) {
        pdfView.document = doc
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.pageShadowsEnabled = true
        pdfView.backgroundColor = .secondarySystemBackground
        pdfView.isFindInteractionEnabled = true
    }

    private var pageIndicator: some View {
        let count = document?.pageCount ?? 0
        return Text("\(page) of \(count)")
            .font(.footnote.monospacedDigit().weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 24)
            .opacity(count > 1 ? 1 : 0)
            .accessibilityLabel("Page \(page) of \(count)")
    }

    private var unlockView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.doc").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("This PDF is password protected").font(.headline)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
                .submitLabel(.go)
                .onSubmit(unlock)
            if wrongPassword { Text("That password didn't work.").font(.footnote).foregroundStyle(.red) }
            Button("Unlock", action: unlock).buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func unlock() {
        guard let doc = document else { return }
        if doc.unlock(withPassword: password) {
            locked = false
            configure(doc)
        } else {
            wrongPassword = true
        }
    }
}

private struct PDFKitHost: UIViewRepresentable {
    let view: PDFView
    @Binding var page: Int

    func makeCoordinator() -> Coordinator { Coordinator(page: $page) }

    func makeUIView(context: Context) -> PDFView {
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.changed(_:)),
                                               name: .PDFViewPageChanged, object: view)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}

    final class Coordinator: NSObject {
        var page: Binding<Int>
        init(page: Binding<Int>) { self.page = page }
        @objc func changed(_ note: Notification) {
            guard let v = note.object as? PDFView, let p = v.currentPage, let doc = v.document else { return }
            page.wrappedValue = doc.index(for: p) + 1
        }
    }
}

private struct ThumbnailStrip: UIViewRepresentable {
    let view: PDFView
    func makeUIView(context: Context) -> PDFThumbnailView {
        let t = PDFThumbnailView()
        t.pdfView = view
        t.layoutMode = .vertical
        t.thumbnailSize = CGSize(width: 60, height: 80)
        t.backgroundColor = .systemBackground.withAlphaComponent(0.92)
        t.widthAnchor.constraint(equalToConstant: 84).isActive = true
        return t
    }
    func updateUIView(_ uiView: PDFThumbnailView, context: Context) {}
}
