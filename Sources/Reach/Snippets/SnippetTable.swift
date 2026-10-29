import ReachKit
import SwiftData
import SwiftUI

/// The snippets of one collection, or all of them: Name | Keyword | Snippet,
/// sorted by name, filtered from the toolbar (S-029).
struct SnippetTable: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query private var snippets: [Snippet]
    let page: SnippetPage
    @State private var filter = ""
    @State private var order = [KeyPathComparator(\Snippet.name, comparator: .localizedStandard)]

    private var visible: [Snippet] {
        let inPage = snippets.filter { snippet in
            guard case .collection(let id) = page else { return true }
            return snippet.collection?.id == id
        }
        let found = filter.isEmpty ? inPage : inPage.filter {
            SnippetSearch.score(filter, name: $0.name, keyword: $0.keyword) != nil
                || $0.text.localizedCaseInsensitiveContains(filter)
        }
        return found.sorted(using: order)
    }

    var body: some View {
        @Bindable var model = model
        Table(visible, selection: $model.selection, sortOrder: $order) {
            TableColumn("Name", value: \.name)
            TableColumn("Keyword", value: \.keyword)
                .width(min: 60, ideal: 90)
            TableColumn("Snippet", value: \.text) { snippet in
                Text(snippet.text.split(whereSeparator: \.isNewline).first.map(String.init) ?? "")
                    .foregroundStyle(.secondary)
                    .help(snippet.text)
            }
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            Button("Delete", role: .destructive) { delete(ids) }
        }
        .onDeleteCommand { delete(model.selection.map { [$0] } ?? []) }
        .overlay {
            if visible.isEmpty {
                ContentUnavailableView {
                    Label(filter.isEmpty ? "No Snippets" : "No Matches", systemImage: "text.quote")
                } description: {
                    Text(filter.isEmpty ? "Add a snippet with + or ⌘N." : "No snippet matches “\(filter)”.")
                } actions: {
                    if filter.isEmpty { Button("Add Snippet") { model.addSnippet() } }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlusMinusBar(addHelp: "Add a snippet (⌘N)", removeHelp: "Delete the selected snippet",
                         canRemove: model.selection != nil,
                         add: { model.addSnippet() }, remove: { delete(model.selection.map { [$0] } ?? []) })
        }
        .searchable(text: $filter, placement: .toolbar, prompt: "Filter")
        .navigationTitle(title)
        .toolbar {
            ToolbarItem {
                Button("New Snippet", systemImage: "plus") { model.addSnippet() }
                    .help("Add a snippet (⌘N)")
            }
        }
    }

    private var title: String {
        guard case .collection(let id) = page else { return SnippetPage.allTitle }
        return (context.model(for: id) as? SnippetCollection)?.name ?? SnippetPage.allTitle
    }

    /// No confirmation: ⌘Z brings it back.
    private func delete(_ ids: Set<PersistentIdentifier>) {
        for id in ids { if let snippet = context.model(for: id) as? Snippet { context.delete(snippet) } }
        if let selection = model.selection, ids.contains(selection) { model.selection = nil }
        try? context.save()
    }
}
