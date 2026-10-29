import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            SnippetList(page: model.sidebar ?? .all)
                .navigationSplitViewColumnWidth(min: 260, ideal: 320)
        } detail: {
            SnippetDetail()
        }
        .task {
            SelfTest.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model, openSettings: openSettings)
        }
    }

    private var sidebar: some View {
        @Bindable var model = model
        return List(SidebarItem.allCases, selection: $model.sidebar) { page in
            Label(page.title, systemImage: page.symbol)
                .tag(page)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 212)
    }
}

struct SnippetList: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \Snippet.createdAt, order: .reverse) private var snippets: [Snippet]
    let page: SidebarItem

    private var visible: [Snippet] {
        page == .starred ? snippets.filter(\.isStarred) : snippets
    }

    var body: some View {
        @Bindable var model = model
        List(visible, selection: $model.selection) { snippet in
            Label(snippet.name, systemImage: snippet.isStarred ? "star.fill" : "text.quote")
                .tag(snippet.id)
                .contextMenu {
                    Button("Delete", role: .destructive) { context.delete(snippet) }
                }
        }
        .overlay {
            if visible.isEmpty {
                ContentUnavailableView(
                    "No Snippets",
                    systemImage: page.symbol,
                    description: Text("Press Command-N to add one.")
                )
            }
        }
        .navigationTitle(page.title)
        .toolbar {
            ToolbarItem {
                Button("New Snippet", systemImage: "plus") { model.addSnippet() }
                    .help("Add a snippet (Command-N)")
            }
        }
    }
}

struct SnippetDetail: View {
    @Environment(AppModel.self) private var model
    @Query private var snippets: [Snippet]

    var body: some View {
        if let snippet = snippets.first(where: { $0.id == model.selection }) {
            @Bindable var snippet = snippet
            Form {
                TextField("Name", text: $snippet.name)
                Toggle("Starred", isOn: $snippet.isStarred)
                TextField("Text", text: $snippet.text, axis: .vertical)
                    .lineLimit(4...)
            }
            .formStyle(.grouped)
            } else {
            ContentUnavailableView("No Selection", systemImage: "sidebar.right")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
    }
}
