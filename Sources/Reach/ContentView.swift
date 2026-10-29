import SwiftData
import SwiftUI

/// The snippets window (S-029): collections, the snippets of the selected
/// one in a table, and the selected snippet's editor.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        NavigationSplitView {
            CollectionSidebar()
                .navigationSplitViewColumnWidth(min: 180, ideal: 212)
        } content: {
            SnippetTable(page: model.page ?? .all)
                // A table of its own per page: updating one table from 3 to 8 rows
                // while the sidebar's selection changes is a reentrant table update.
                .id(model.page)
                .navigationSplitViewColumnWidth(min: 360, ideal: 480)
        } detail: {
            SnippetEditor()
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        }
        // Edits and deletes in this window can be undone with ⌘Z.
        .onAppear { context.undoManager = undoManager }
        .onChange(of: undoManager) { context.undoManager = undoManager }
        .task {
            SeedData.insertIfRequested(into: model)
            SelfTest.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model, openSettings: openSettings)
        }
    }
}

/// + and − under a list, like the lists in System Settings.
struct PlusMinusBar: View {
    let addHelp: String
    let removeHelp: String
    let canRemove: Bool
    let add: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: add) {
                Image(systemName: "plus").frame(width: Space.xl, height: Space.xl)
            }
            .help(addHelp)
            .accessibilityLabel(addHelp)
            Button(action: remove) {
                Image(systemName: "minus").frame(width: Space.xl, height: Space.xl)
            }
            .disabled(!canRemove)
            .help(removeHelp)
            .accessibilityLabel(removeHelp)
            Spacer()
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, Space.sm)
        .padding(.vertical, Space.xs)
        .background(.bar)
    }
}
