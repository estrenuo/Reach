import ReachKit
import SwiftUI

/// A workflow's objects and the lines between them (S-044), where its
/// uidata puts them. Drag a card, or select it and press an arrow key, to
/// move it (S-061); the new place is saved in info.plist at once.
/// ⌘-click, ⇧-click and ⌘A select several; Delete removes them (S-065).
struct WorkflowCanvasView: View {
    let workflow: Workflow
    private var library = WorkflowLibrary.shared
    @Environment(\.undoManager) private var undo
    @State private var drag: (uid: String, by: CGSize)?
    @FocusState private var focused: Bool

    init(workflow: Workflow) {
        self.workflow = workflow
    }

    /// The single selected card (S-061): the arrow keys move it.
    private var selected: String? { library.selectedObject }

    static let card = CGSize(width: 168, height: 56)

    var body: some View {
        if workflow.objects.isEmpty {
            ContentUnavailableView("No Objects", systemImage: "square.dashed",
                                   description: Text("This workflow has nothing on its canvas."))
        } else {
            let positions = shownPositions
            let size = canvasSize(positions)
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { library.selectedObjects = [] }
                    Lines(workflow: workflow, positions: positions)
                    ForEach(workflow.objects) { object in
                        if let point = positions[object.uid] {
                            card(object, at: point)
                        }
                    }
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
            }
            .defaultScrollAnchor(.topLeading)
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
                guard let selected else { return .ignored }
                let steps = press.modifiers.contains(.shift) ? 5.0 : 1.0
                nudge(selected, press.key, by: steps * WorkflowEdit.grid)
                return .handled
            }
            .onKeyPress(.escape) {
                guard !library.selectedObjects.isEmpty else { return .ignored }
                library.selectedObjects = []
                return .handled
            }
            .onKeyPress(keys: [.delete, .deleteForward]) { _ in
                guard !library.selectedObjects.isEmpty else { return .ignored }
                deleteSelection()
                return .handled
            }
            .onDeleteCommand(perform: deleteAction)
            .onCommand(#selector(NSResponder.selectAll(_:))) {
                library.selectedObjects = Set(workflow.objects.map(\.uid))
            }
            .onChange(of: workflow.id) { library.selectedObjects = [] }
            .accessibilityLabel("Canvas of \(workflow.name)")
        }
    }

    private func card(_ object: WorkflowObject, at point: WorkflowPoint) -> some View {
        let dragging = drag?.uid == object.uid
        let isSelected = library.selectedObjects.contains(object.uid)
        return ObjectCard(object: object, selected: isSelected)
            .frame(width: Self.card.width, height: Self.card.height)
            .shadow(radius: dragging ? Space.sm : 0)
            .offset(x: point.x, y: point.y) // grid: ok canvas coordinates from the workflow
            .zIndex(dragging ? 1 : 0)
            .gesture(DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if !isSelected { library.select(object.uid) }
                    drag = (object.uid, value.translation)
                }
                .onEnded { value in
                    drag = nil
                    guard let from = WorkflowLayout.positions(workflow)[object.uid] else { return }
                    library.move(object.uid, to: WorkflowPoint(x: from.x + value.translation.width, y: from.y + value.translation.height),
                                 in: workflow, undo: undo)
                })
            .onTapGesture {
                let keys = NSEvent.modifierFlags
                library.select(object.uid, command: keys.contains(.command), shift: keys.contains(.shift))
                focused = true
            }
            .contextMenu {
                Button("Delete", role: .destructive) { delete(object.uid) }
            }
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { library.select(object.uid) }
            .accessibilityAction(named: "Delete") { delete(object.uid) }
            .accessibilityAction(named: "Move Left") { nudge(object.uid, .leftArrow, by: WorkflowEdit.grid) }
            .accessibilityAction(named: "Move Right") { nudge(object.uid, .rightArrow, by: WorkflowEdit.grid) }
            .accessibilityAction(named: "Move Up") { nudge(object.uid, .upArrow, by: WorkflowEdit.grid) }
            .accessibilityAction(named: "Move Down") { nudge(object.uid, .downArrow, by: WorkflowEdit.grid) }
    }

    /// The saved positions, with the card being dragged where the pointer has it.
    private var shownPositions: [String: WorkflowPoint] {
        var positions = WorkflowLayout.positions(workflow)
        if let drag, let point = positions[drag.uid] {
            positions[drag.uid] = WorkflowPoint(x: max(0, point.x + drag.by.width), y: max(0, point.y + drag.by.height))
        }
        return positions
    }

    /// Deletes the selection when `uid` is in it, else only that card (context menu, VoiceOver).
    private func delete(_ uid: String) {
        let uids = library.selectedObjects.contains(uid) ? library.selectedObjects : [uid]
        library.delete(uids, in: workflow, undo: undo)
    }

    /// Edit > Delete, off while nothing is selected.
    private var deleteAction: (() -> Void)? {
        library.selectedObjects.isEmpty ? nil : { deleteSelection() }
    }

    private func deleteSelection() {
        library.delete(library.selectedObjects, in: workflow, undo: undo)
    }

    private func nudge(_ uid: String, _ key: KeyEquivalent, by step: Double) {
        guard let point = WorkflowLayout.positions(workflow)[uid] else { return }
        let (dx, dy): (Double, Double) = switch key {
        case .leftArrow: (-step, 0)
        case .rightArrow: (step, 0)
        case .upArrow: (0, -step)
        default: (0, step)
        }
        library.move(uid, to: WorkflowPoint(x: point.x + dx, y: point.y + dy), in: workflow, undo: undo)
    }

    private func canvasSize(_ positions: [String: WorkflowPoint]) -> CGSize {
        let width = (positions.values.map(\.x).max() ?? 0) + Self.card.width + Space.section
        let height = (positions.values.map(\.y).max() ?? 0) + Self.card.height + Space.section
        return CGSize(width: width, height: height)
    }
}

/// A curved line from the right of each card to the left of the next,
/// with the key held for it, such as ⌘, halfway along.
private struct Lines: View {
    let workflow: Workflow
    let positions: [String: WorkflowPoint]

    private struct Line: Identifiable {
        var id: String
        var from: CGPoint
        var to: CGPoint
        var keys: String
    }

    private var lines: [Line] {
        let card = WorkflowCanvasView.card
        return workflow.connections.flatMap { uid, connections in
            connections.enumerated().compactMap { index, connection -> Line? in
                guard let start = positions[uid], let end = positions[connection.to] else { return nil }
                return Line(id: "\(uid)-\(index)", from: CGPoint(x: start.x + card.width, y: start.y + card.height / 2),
                            to: CGPoint(x: end.x, y: end.y + card.height / 2), keys: Self.keys(connection.modifiers))
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for line in lines {
                    var path = Path()
                    path.move(to: line.from)
                    let bend = max(40, abs(line.to.x - line.from.x) / 2)
                    path.addCurve(to: line.to, control1: CGPoint(x: line.from.x + bend, y: line.from.y),
                                  control2: CGPoint(x: line.to.x - bend, y: line.to.y))
                    context.stroke(path, with: .style(.secondary), lineWidth: 2)
                }
            }
            ForEach(lines.filter { !$0.keys.isEmpty }) { line in
                Text(line.keys)
                    .font(.caption.bold())
                    .padding(.horizontal, Space.xs)
                    .background(.background, in: Capsule())
                    .position(x: (line.from.x + line.to.x) / 2, y: (line.from.y + line.to.y) / 2) // grid: ok halfway along a line
            }
        }
    }

    static func keys(_ modifiers: Int) -> String {
        var keys = ""
        if modifiers & WorkflowConnection.control != 0 { keys += "⌃" }
        if modifiers & WorkflowConnection.option != 0 { keys += "⌥" }
        if modifiers & WorkflowConnection.shift != 0 { keys += "⇧" }
        if modifiers & WorkflowConnection.command != 0 { keys += "⌘" }
        return keys
    }
}

/// One object: its kind and what it does, colored by its category.
struct ObjectCard: View {
    let object: WorkflowObject
    var selected = false

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: Self.symbol(object.category))
                .font(.title3)
                .foregroundStyle(Self.color(object.category))
                .frame(width: Space.xxl)
            VStack(alignment: .leading, spacing: 0) {
                Text(object.kindName)
                    .font(.callout.bold())
                    .lineLimit(1)
                if !object.summary.isEmpty {
                    Text(object.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.sm)
        .background {
            RoundedRectangle(cornerRadius: Radius.row).fill(.background)
            RoundedRectangle(cornerRadius: Radius.row).fill(Self.color(object.category).opacity(0.12))
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.row).strokeBorder(Self.color(object.category).opacity(0.6)))
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: Radius.row).strokeBorder(Palette.accent, lineWidth: 2)
            }
        }
        .help("\(object.kindName): \(object.summary)")
        .accessibilityElement(children: .combine)
    }

    static func color(_ category: WorkflowCategory) -> Color {
        switch category {
        case .trigger: .red
        case .input: .purple
        case .action: .blue
        case .utility: .gray
        case .output: .green
        case .other: .secondary
        }
    }

    static func symbol(_ category: WorkflowCategory) -> String {
        switch category {
        case .trigger: "bolt"
        case .input: "text.cursor"
        case .action: "play"
        case .utility: "arrow.triangle.branch"
        case .output: "arrow.up.forward.square"
        case .other: "questionmark.square"
        }
    }
}
