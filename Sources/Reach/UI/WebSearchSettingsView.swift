import ReachKit
import SwiftUI

/// Settings > Web Search (S-016): on the Searches page custom searches first,
/// added in a sheet, then the built-ins with a filter. The URLs page has the
/// typed URLs and the URL history (S-017). Every search is on or off; built-ins
/// carry a lock: they can be switched off, not changed.
struct WebSearchSettingsView: View {
    @Bindable private var settings = WebSearchSettings.shared
    @State private var filter = ""
    @State private var onlyOn = false
    @State private var selected: String?
    /// The search the sheet edits; a new one for Add Custom Search.
    @State private var editing: WebSearch?

    /// Built-ins that pass the filter and the "only enabled" checkbox.
    private var shown: [WebSearch] {
        let text = filter.trimmingCharacters(in: .whitespaces)
        return settings.searches.filter { search in
            search.isBuiltIn && (!onlyOn || search.isOn)
                && (text.isEmpty || Matcher.score(query: text, title: search.keyword) != nil
                    || Matcher.score(query: text, title: search.title) != nil)
        }
    }

    var body: some View {
        Section {
            Picker("Page", selection: $settings.page) {
                ForEach(WebSearchSettings.Page.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
        switch settings.page {
        case .searches: searches
        case .urls: URLSettingsView()
        }
    }

    @ViewBuilder
    private var searches: some View {
        Section {
            if settings.custom.isEmpty {
                Text("No custom searches")
                    .foregroundStyle(.secondary)
            }
            ForEach(settings.custom) { search in
                row(search)
                    .contentShape(Rectangle())
                    .listRowBackground(selected == search.id ? Color.accentColor.opacity(0.2) : nil)
                    .onTapGesture(count: 2) { editing = search }
                    .onTapGesture { selected = search.id }
                    .contextMenu {
                        Button("Edit…") { editing = search }
                        Button("Remove") { remove(search.id) }
                    }
            }
            HStack(spacing: 0) {
                Button {
                    if let selected { remove(selected) }
                } label: {
                    Image(systemName: "minus").frame(width: Space.xl, height: Space.xl)
                }
                .disabled(!canRemove)
                .help("Remove the selected custom search")
                .accessibilityLabel("Remove the selected custom search")
                Spacer()
                Button("Add Custom Search…") { editing = WebSearch(keyword: "", title: "", url: "") }
            }
            .buttonStyle(.borderless)
        } header: {
            Text("Custom Searches")
        } footer: {
            Text("Type a keyword and a space, then the words: “wiki alfred” searches Wikipedia. Double-click a custom search to change it.")
                .foregroundStyle(.secondary)
        }
        Section {
            HStack {
                TextField("Filter", text: $filter, prompt: Text("Filter"))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 200)
                    .accessibilityLabel("Filter built-in searches")
                Spacer()
                Toggle("Only show enabled searches", isOn: $onlyOn)
                    .toggleStyle(.checkbox)
            }
            if shown.isEmpty {
                Text(filter.isEmpty ? "No enabled searches" : "No searches match “\(filter)”")
                    .foregroundStyle(.secondary)
            }
            ForEach(shown) { search in
                row(search)
            }
        } header: {
            Text("Built-in Searches")
        } footer: {
            Text("Searches that are off fall through to the fallbacks.")
                .foregroundStyle(.secondary)
        }
        .sheet(item: $editing) { search in
            CustomSearchSheet(search: search, isNew: !settings.custom.contains { $0.id == search.id },
                              taken: settings.taken) { saved in
                settings.save(saved)
                selected = saved.id
            }
        }
    }

    private func row(_ search: WebSearch) -> some View {
        SearchRow(search: search, selected: selected == search.id,
                  isOn: Binding(get: { search.isOn }, set: { settings.set(search.id, on: $0) }))
    }

    private var canRemove: Bool {
        settings.custom.contains { $0.id == selected }
    }

    private func remove(_ id: String) {
        settings.remove(id)
        if selected == id { selected = nil }
    }
}

/// One search: a checkbox, its keyword and the text its row shows.
private struct SearchRow: View {
    let search: WebSearch
    let selected: Bool
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Space.sm) {
            Toggle(isOn: $isOn) { EmptyView() }
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityLabel("\(search.title(for: "")), keyword \(search.keyword)")
            Image(systemName: search.symbol)
                .foregroundStyle(Palette.accentText)
                .frame(width: Space.lg)
                .accessibilityHidden(true)
            Text(search.keyword)
                .frame(width: 88, alignment: .leading)
                .lineLimit(1)
            Text(search.title)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(search.url)
            Spacer(minLength: Space.sm)
            if search.isBuiltIn {
                Image(systemName: "lock")
                    .foregroundStyle(.tertiary)
                    .help("Built in: you can switch it off, not change it")
                    .accessibilityLabel("Built in")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Add Custom Search, or Edit Custom Search for one that exists. Add stays
/// off until the fields make a search; the problem shows under the fields.
private struct CustomSearchSheet: View {
    let search: WebSearch
    let isNew: Bool
    let taken: [String: String]
    let save: (WebSearch) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var keyword = ""
    @State private var url = ""
    @State private var tried = false

    private var problem: String? {
        WebSearches.problem(title: title, keyword: keyword.trimmingCharacters(in: .whitespaces), url: url, taken: taken)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text(isNew ? "Add Custom Search" : "Edit Custom Search")
                .font(.headline)
            Form {
                TextField("Title", text: $title, prompt: Text("Search DuckDuckGo for “{query}”"))
                TextField("Keyword", text: $keyword, prompt: Text("ddg"))
                TextField("URL", text: $url, prompt: Text("https://duckduckgo.com/?q={query}"))
            }
            .formStyle(.columns)
            Text("Put {query} where the words go, in the title and the URL. A URL without {query} opens when you type the keyword alone.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if tried, let problem {
                Text(problem)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") {
                    tried = true
                    guard problem == nil else { return }
                    var saved = search
                    saved.title = title.trimmingCharacters(in: .whitespaces)
                    saved.keyword = keyword.trimmingCharacters(in: .whitespaces).lowercased()
                    saved.url = url.trimmingCharacters(in: .whitespaces)
                    save(saved)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.xl)
        .frame(width: 440)
        .onAppear {
            title = search.title
            keyword = search.keyword
            url = search.url
        }
    }
}
