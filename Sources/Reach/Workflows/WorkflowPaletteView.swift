import ReachKit
import SwiftUI

/// The palette beside the canvas (S-063): the objects Reach runs, by
/// category, collapsed until opened or searched. Drag a row onto the canvas,
/// or select it and press Return, to add that object.
struct WorkflowPaletteView: View {
    let workflow: Workflow
    @Bindable private var palette = WorkflowPaletteState.shared
    private var library = WorkflowLibrary.shared
    @Environment(\.undoManager) private var undo
    @State private var selection: String?
    @FocusState private var focus: Field?

    private enum Field { case search, list }

    static let width: CGFloat = 240

    init(workflow: Workflow) {
        self.workflow = workflow
    }

    private var sections: [(category: WorkflowCategory, kinds: [WorkflowKind])] { WorkflowPalette.sections(filter: palette.filter) }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(Space.sm)
            Divider()
            list
        }
        .frame(width: Self.width)
        .onChange(of: palette.wantsSearch, initial: true) {
            guard palette.wantsSearch else { return }
            // After this update, so a palette that just opened has its field to focus.
            Task { @MainActor in
                focus = .search
                palette.wantsSearch = false
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Palette")
    }

    private var searchField: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search Objects", text: $palette.filter)
                .textFieldStyle(.plain)
                .focused($focus, equals: .search)
                .onSubmit { addSelectedOrFirst() }
                .onKeyPress(.downArrow) {
                    selection = selection ?? sections.first?.kinds.first?.type
                    focus = .list
                    return .handled
                }
                .onKeyPress(.escape) {
                    if palette.filter.isEmpty {
                        focus = nil
                    } else {
                        palette.filter = ""
                    }
                    return .handled
                }
                .accessibilityLabel("Search Objects")
            if !palette.filter.isEmpty {
                Button {
                    palette.filter = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Clear the search")
                .accessibilityLabel("Clear the search")
            }
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, Space.xs)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Radius.row))
        .gridProbe("palette-search", area: "workflow-palette", edge: nil)
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(sections, id: \.category) { section in
                Section(isExpanded: expanded(section.category)) {
                    ForEach(section.kinds) { kind in
                        PaletteRow(kind: kind)
                            .tag(kind.type)
                            .draggable(kind.type) {
                                ObjectCard(object: WorkflowObject(uid: "", type: kind.type, config: kind.config))
                                    .frame(width: WorkflowCanvasView.card.width, height: WorkflowCanvasView.card.height)
                            }
                            .accessibilityAction(named: "Add to Canvas") { add(kind) }
                    }
                } header: {
                    Text(WorkflowPalette.title(section.category))
                }
            }
        }
        .listStyle(.sidebar)
        .focused($focus, equals: .list)
        .contextMenu(forSelectionType: String.self) { types in
            if let type = types.first, let kind = WorkflowPalette.kind(type) {
                Button("Add to Canvas") { add(kind) }
            }
        } primaryAction: { types in
            if let type = types.first, let kind = WorkflowPalette.kind(type) { add(kind) }
        }
        .onKeyPress(.return) {
            guard let type = selection, let kind = WorkflowPalette.kind(type) else { return .ignored }
            add(kind)
            return .handled
        }
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView.search(text: palette.filter)
            }
        }
    }

    /// Opened by hand, or open because the search found something in it.
    private func expanded(_ category: WorkflowCategory) -> Binding<Bool> {
        Binding(get: { !palette.filter.isEmpty || palette.expanded.contains(category) },
                set: { open in
                    if open { palette.expanded.insert(category) } else { palette.expanded.remove(category) }
                })
    }

    private func addSelectedOrFirst() {
        let shown = sections.flatMap(\.kinds)
        guard let kind = shown.first(where: { $0.type == selection }) ?? shown.first else { return }
        add(kind)
    }

    private func add(_ kind: WorkflowKind) {
        guard let current = library.workflow(workflow.id) else { return }
        library.add(kind, at: nil, in: current, undo: undo)
        AccessibilityNotification.Announcement("Added \(kind.name)").post()
    }
}

/// One kind in the palette: its category's symbol and color, and its name.
private struct PaletteRow: View {
    let kind: WorkflowKind

    var body: some View {
        Label {
            Text(kind.name)
        } icon: {
            Image(systemName: ObjectCard.symbol(kind.category))
                .foregroundStyle(ObjectCard.color(kind.category))
        }
        .help("Drag onto the canvas, or press Return, to add a \(kind.name)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.name), \(WorkflowPalette.singular(kind.category))")
    }
}
