import ReachKit
import SwiftData
import SwiftUI

/// All Snippets, then the collections by name, with + and − below (S-029).
struct CollectionSidebar: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \SnippetCollection.name) private var collections: [SnippetCollection]
    @State private var naming: Naming?
    @State private var deleting: SnippetCollection?

    /// The name sheet: for a new collection, or to rename one.
    struct Naming: Identifiable {
        var collection: SnippetCollection?
        var name: String
        var id: String { collection.map { "\($0.id)" } ?? "new" }
    }

    var body: some View {
        @Bindable var model = model
        List(selection: $model.page) {
            Label(SnippetPage.allTitle, systemImage: "text.quote")
                .tag(SnippetPage.all)
            Section("Collections") {
                ForEach(collections) { collection in
                    Label(collection.name, systemImage: "folder")
                        .badge(collection.snippets?.count ?? 0)
                        .tag(SnippetPage.collection(collection.id))
                        .contextMenu {
                            Button("Rename…") { naming = Naming(collection: collection, name: collection.name) }
                            Button("Delete…", role: .destructive) { deleting = collection }
                        }
                }
                if collections.isEmpty {
                    Text("No Collections")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlusMinusBar(addHelp: "Add a collection", removeHelp: "Delete the selected collection and its snippets",
                         canRemove: model.currentCollection != nil,
                         add: { naming = Naming(collection: nil, name: "") },
                         remove: { deleting = model.currentCollection })
        }
        .sheet(item: $naming) { naming in
            CollectionNameSheet(naming: naming) { name in
                if let collection = naming.collection {
                    collection.name = SnippetName.clean(name, fallback: collection.name)
                } else {
                    model.addCollection(name: name)
                }
            }
        }
        .confirmationDialog(deleteTitle, isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) {
                if let deleting { model.delete(deleting) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can undo this with ⌘Z.")
        }
    }

    private var deleteTitle: String {
        guard let deleting else { return "" }
        let count = deleting.snippets?.count ?? 0
        return count == 0 ? "Delete “\(deleting.name)”?"
            : "Delete “\(deleting.name)” and its \(count) \(count == 1 ? "snippet" : "snippets")?"
    }
}

/// "New Collection" or "Rename Collection": one name field; Return confirms, Esc cancels.
private struct CollectionNameSheet: View {
    let naming: CollectionSidebar.Naming
    let done: (String) -> Void
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(naming.collection == nil ? "New Collection" : "Rename Collection")
                .font(.headline)
            TextField("Name", text: $name, prompt: Text("Work"))
                .frame(width: 280)
                .onSubmit(confirm)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(naming.collection == nil ? "Create" : "Rename", action: confirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.lg)
        .onAppear { name = naming.name }
    }

    private func confirm() {
        done(name)
        dismiss()
    }
}
