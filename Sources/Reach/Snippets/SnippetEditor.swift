import ReachKit
import SwiftData
import SwiftUI

/// The selected snippet: name, keyword, collection and text, saved as you type (S-029).
struct SnippetEditor: View {
    @Environment(AppModel.self) private var model
    @Query private var snippets: [Snippet]
    @Query(sort: \SnippetCollection.name) private var collections: [SnippetCollection]

    var body: some View {
        if let snippet = snippets.first(where: { $0.id == model.selection }) {
            @Bindable var snippet = snippet
            Form {
                TextField("Name", text: $snippet.name)
                TextField("Keyword", text: Binding(get: { snippet.keyword }, set: { snippet.keyword = SnippetName.keyword($0) }),
                          prompt: Text("sig"))
                if let other = clash(snippet) {
                    Text("“\(other.name)” has this keyword too.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                Picker("Collection", selection: $snippet.collection) {
                    ForEach(collections) { Text($0.name).tag(Optional($0)) }
                }
                Section("Snippet") {
                    TextEditor(text: $snippet.text)
                        .font(.body)
                        .frame(minHeight: 160)
                        .accessibilityLabel("Snippet text")
                }
            }
            .formStyle(.grouped)
        } else {
            ContentUnavailableView("No Snippet Selected", systemImage: "text.quote",
                                   description: Text("Select a snippet to edit it."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Another snippet with the same keyword; typing it would find both.
    private func clash(_ snippet: Snippet) -> Snippet? {
        guard !snippet.keyword.isEmpty else { return nil }
        return snippets.first { $0.id != snippet.id && $0.keyword.caseInsensitiveCompare(snippet.keyword) == .orderedSame }
    }
}
