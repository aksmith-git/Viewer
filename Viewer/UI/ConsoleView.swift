import SwiftUI

/// The page's console: messages, errors, and a JavaScript prompt.
struct ConsoleView: View {
    @ObservedObject var model: WebModel
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var filter: Filter = .all
    @FocusState private var focused: Bool

    enum Filter: String, CaseIterable { case all = "All", errors = "Errors", warnings = "Warnings", logs = "Logs" }

    private var shown: [ConsoleEntry] {
        switch filter {
        case .all: return model.console
        case .errors: return model.console.filter { $0.level == "error" }
        case .warnings: return model.console.filter { $0.level == "warn" }
        case .logs: return model.console.filter { ["log", "info", "debug"].contains($0.level) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List(shown) { entry in
                    ConsoleRow(entry: entry).id(entry.id)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowBackground(background(for: entry.level))
                }
                .listStyle(.plain)
                .overlay {
                    if shown.isEmpty {
                        ContentUnavailableView("No Messages", systemImage: "terminal",
                                               description: Text("console.log output and errors from the page appear here."))
                    }
                }
                .onChange(of: model.console.count) {
                    if let last = shown.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .safeAreaInset(edge: .bottom) { prompt }
            .navigationTitle("Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button { UIPasteboard.general.string = model.console.map { "[\($0.level)] \($0.message)" }.joined(separator: "\n") } label: {
                            Label("Copy All", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive) { model.clearConsole() } label: { Label("Clear", systemImage: "trash") }
                    } label: { Label("Actions", systemImage: "ellipsis.circle") }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color(.systemBackground))
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    private var prompt: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            TextField("Run JavaScript", text: $input)
                .font(.system(.callout, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focused)
                .onSubmit(run)
            if !input.isEmpty {
                Button(action: run) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                    .accessibilityLabel("Run")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func run() {
        let code = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        model.evaluate(code)
        input = ""
        focused = true
    }

    private func background(for level: String) -> Color {
        switch level {
        case "error": return .red.opacity(0.08)
        case "warn": return .yellow.opacity(0.10)
        default: return .clear
        }
    }
}

struct ConsoleRow: View {
    let entry: ConsoleEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).font(.caption).foregroundStyle(tint).frame(width: 14)
            Text(entry.message)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(entry.level == "error" ? .red : entry.level == "result" ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.time, format: .dateTime.hour().minute().second())
                .font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
        }
    }

    private var symbol: String {
        switch entry.level {
        case "error": return "xmark.octagon.fill"
        case "warn": return "exclamationmark.triangle.fill"
        case "info": return "info.circle.fill"
        case "debug": return "ant.fill"
        case "input": return "chevron.right"
        case "result": return "arrow.turn.down.left"
        default: return "circle.fill"
        }
    }

    private var tint: Color {
        switch entry.level {
        case "error": return .red
        case "warn": return .orange
        case "info": return .blue
        case "input": return .accentColor
        default: return .secondary
        }
    }
}
