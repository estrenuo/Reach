import ReachKit
import SwiftUI

/// Settings > Search > Fallbacks (S-018): when they show, and which web
/// searches they are, edited and ordered in a sheet.
struct FallbacksSection: View {
    @Bindable private var settings = WebSearchSettings.shared

    var body: some View {
        Section {
            Picker("Show fallbacks", selection: $settings.fallbackMode) {
                ForEach(FallbackMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            LabeledContent {
                Button("Edit Fallbacks…") { settings.editingFallbacks = true }
            } label: {
                Text("Web searches")
                Text(summary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(summary)
            }
        } header: {
            Text("Fallbacks")
        } footer: {
            Text("Web searches for what you typed, in this order. Any web search can be a fallback, also when its keyword is off.")
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $settings.editingFallbacks) { FallbacksSheet() }
    }

    private var summary: String {
        let names = settings.fallbacks.map { $0.title(for: "").replacingOccurrences(of: " for “…”", with: "")
            .replacingOccurrences(of: "Search ", with: "") }
        return names.isEmpty ? "None" : names.joined(separator: ", ")
    }
}

/// Edit Fallbacks: the list in order, dragged or moved with the menu, + to
/// add any web search that takes words, − to take one out, Reset for Alfred's three.
private struct FallbacksSheet: View {
    @Bindable private var settings = WebSearchSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Edit Fallbacks")
                .font(.headline)
            List(selection: $selected) {
                ForEach(settings.fallbacks) { search in
                    HStack(spacing: Space.sm) {
                        Image(systemName: search.symbol)
                            .foregroundStyle(Palette.accentText)
                            .frame(width: Space.lg)
                            .accessibilityHidden(true)
                        Text(search.title(for: ""))
                            .lineLimit(1)
                        Spacer()
                        Text(search.keyword)
                            .foregroundStyle(.secondary)
                    }
                    .tag(search.id)
                    .contextMenu {
                        Button("Move Up") { move(search.id, by: -1) }
                            .disabled(settings.fallbackIDs.first == search.id)
                        Button("Move Down") { move(search.id, by: 1) }
                            .disabled(settings.fallbackIDs.last == search.id)
                        Button("Remove") { remove(search.id) }
                    }
                }
                .onMove { from, to in settings.fallbackIDs.move(fromOffsets: from, toOffset: to) }
            }
            .frame(height: 220)
            .overlay {
                if settings.fallbacks.isEmpty {
                    Text("No fallbacks: a query without results shows nothing.")
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Fallbacks, in order")
            HStack(spacing: 0) {
                Menu {
                    ForEach(FallbackList.choices(ids: settings.fallbackIDs, from: settings.searches)) { search in
                        Button(search.title(for: "")) {
                            settings.fallbackIDs.append(search.id)
                            selected = search.id
                        }
                    }
                } label: {
                    Image(systemName: "plus").frame(width: Space.xl, height: Space.xl)
                }
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Add a web search as a fallback")
                .accessibilityLabel("Add a web search as a fallback")
                Button {
                    if let selected { remove(selected) }
                } label: {
                    Image(systemName: "minus").frame(width: Space.xl, height: Space.xl)
                }
                .disabled(selected == nil)
                .help("Remove the selected fallback")
                .accessibilityLabel("Remove the selected fallback")
                Button {
                    if let selected { move(selected, by: -1) }
                } label: {
                    Image(systemName: "chevron.up").frame(width: Space.xl, height: Space.xl)
                }
                .disabled(selected == nil || settings.fallbackIDs.first == selected)
                .help("Move the selected fallback up")
                .accessibilityLabel("Move the selected fallback up")
                Button {
                    if let selected { move(selected, by: 1) }
                } label: {
                    Image(systemName: "chevron.down").frame(width: Space.xl, height: Space.xl)
                }
                .disabled(selected == nil || settings.fallbackIDs.last == selected)
                .help("Move the selected fallback down")
                .accessibilityLabel("Move the selected fallback down")
                Spacer()
                Button("Reset") {
                    settings.fallbackIDs = FallbackList.standard
                    selected = nil
                }
                .help("Put back Google, Amazon and Wikipedia")
            }
            .buttonStyle(.borderless)
            Text("Drag to change the order. The first fallback is selected when nothing else matches.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.xl)
        .frame(width: 440)
        // Drops ids of searches that were removed, so the rows and the ids line up for moving.
        .onAppear { settings.fallbackIDs = settings.fallbacks.map(\.id) }
    }

    private func move(_ id: String, by step: Int) {
        guard let index = settings.fallbackIDs.firstIndex(of: id) else { return }
        let target = index + step
        guard settings.fallbackIDs.indices.contains(target) else { return }
        settings.fallbackIDs.swapAt(index, target)
    }

    private func remove(_ id: String) {
        settings.fallbackIDs.removeAll { $0 == id }
        if selected == id { selected = nil }
    }
}
