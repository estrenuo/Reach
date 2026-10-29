import ReachKit
import SwiftUI

/// Settings > Web Search > URLs (S-017): how typed URLs are read, and the
/// URL history with a filter, − for one URL, and Clear… for all of them.
struct URLSettingsView: View {
    @Environment(AppModel.self) private var model
    @Bindable private var settings = WebSearchSettings.shared
    @State private var filter = ""
    @State private var selected: String?
    @State private var confirmingClear = false

    private var history: URLHistory { model.launcherModel.history }

    private var shown: [URLHistory.Entry] {
        let text = filter.trimmingCharacters(in: .whitespaces)
        return history.entries.filter { text.isEmpty || Matcher.score(query: text, title: TypedURL.display($0.url)) != nil }
    }

    var body: some View {
        Section {
            Toggle("Recognize URLs", isOn: $settings.recognizesURLs)
            Picker("Scheme for a domain typed without one", selection: $settings.scheme) {
                Text("https").tag("https")
                Text("http").tag("http")
            }
            .disabled(!settings.recognizesURLs)
            Toggle("Treat URL schemes without // as URLs", isOn: $settings.withoutSlashes)
                .disabled(!settings.recognizesURLs)
        } header: {
            Text("URLs")
        } footer: {
            // Verbatim, so the examples stay text instead of links.
            Text(verbatim: "Typing “example.com” opens \(settings.scheme)://example.com. With schemes without //, a word and a colon is a URL too, like mailto:you@example.com.")
                .foregroundStyle(.secondary)
        }
        Section {
            Toggle("Remember URLs you open from Reach", isOn: $settings.keepsHistory)
            Picker("Remove a URL when not used for", selection: $settings.retention) {
                ForEach(URLRetention.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .disabled(!settings.keepsHistory)
            .onChange(of: settings.retention) { history.prune() }
            TextField("Filter", text: $filter, prompt: Text("Filter"))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .accessibilityLabel("Filter the URL history")
            if shown.isEmpty {
                Text(filter.isEmpty ? "No URLs yet" : "No URLs match “\(filter)”")
                    .foregroundStyle(.secondary)
            }
            ForEach(shown) { entry in
                LabeledContent {
                    Text(entry.lastUsed.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                } label: {
                    Text(entry.url)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(entry.url)
                }
                .contentShape(Rectangle())
                .listRowBackground(selected == entry.url ? Color.accentColor.opacity(0.2) : nil)
                .onTapGesture { selected = entry.url }
                .contextMenu { Button("Remove") { remove(entry.url) } }
                .accessibilityAddTraits(selected == entry.url ? .isSelected : [])
            }
            HStack(spacing: 0) {
                Button {
                    if let selected { remove(selected) }
                } label: {
                    Image(systemName: "minus").frame(width: Space.xl, height: Space.xl)
                }
                .disabled(selected == nil)
                .help("Remove the selected URL from the history")
                .accessibilityLabel("Remove the selected URL from the history")
                Spacer()
                Button("Clear…") { confirmingClear = true }
                    .disabled(history.entries.isEmpty)
                    .help("Remove every URL from the history")
            }
            .buttonStyle(.borderless)
        } header: {
            Text("URL History")
        } footer: {
            Text("URLs you opened come back as results when you type part of them. Last opened on the right.")
                .foregroundStyle(.secondary)
        }
        .confirmationDialog("Clear URL History?", isPresented: $confirmingClear) {
            Button("Clear", role: .destructive) {
                history.clear()
                selected = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reach forgets all \(history.entries.count) URLs. This can’t be undone.")
        }
    }

    private func remove(_ url: String) {
        history.remove(url)
        if selected == url { selected = nil }
    }
}
