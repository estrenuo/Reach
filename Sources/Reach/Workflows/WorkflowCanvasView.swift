import ReachKit
import SwiftUI

/// A workflow's objects and the lines between them (S-044), where its
/// uidata puts them. Drag a card, or select it and press an arrow key, to
/// move it (S-061); the new place is saved in info.plist at once.
struct WorkflowCanvasView: View {
    let workflow: Workflow
    private var library = WorkflowLibrary.shared
    @Environment(\.undoManager) private var undo
    @State private var drag: (uid: String, by: CGSize)?
    @FocusState private var focused: Bool

    init(workflow: Workflow) {
        self.workflow = workflow
    }

    /// The selected card (S-061): the arrow keys move it.
    private var selected: String? {
        get { library.selectedObject }
        nonmutating set { library.selectedObject = newValue }
    }

    static let card = CGSize(width: 168, height: 56)

    var body: some View {
        if workflow.objects.isEmpty {
            ContentUnavailableView("No Objects", systemImage: "square.dashed",
                                   description: Text("This workflow has nothing on its canvas. Add objects from the palette."))
                .dropDestination(for: String.self) { types, location in drop(types, at: location) }
        } else {
            let positions = shownPositions
            let size = canvasSize(positions)
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { selected = nil }
                    Lines(workflow: workflow, positions: positions)
                    ForEach(workflow.objects) { object in
                        if let point = positions[object.uid] {
                            card(object, at: point)
                        }
                    }
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .dropDestination(for: String.self) { types, location in drop(types, at: location) }
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
            .onKeyPress("/") {
                WorkflowPaletteState.shared.search()
                return .handled
            }
            .onKeyPress(.escape) {
                guard selected != nil else { return .ignored }
                selected = nil
                return .handled
            }
            .onChange(of: workflow.id) { selected = nil }
            .accessibilityLabel("Canvas of \(workflow.name)")
        }
    }

    private func card(_ object: WorkflowObject, at point: WorkflowPoint) -> some View {
        let dragging = drag?.uid == object.uid
        return ObjectCard(object: object, selected: selected == object.uid)
            .frame(width: Self.card.width, height: Self.card.height)
            .shadow(radius: dragging ? Space.sm : 0)
            .offset(x: point.x, y: point.y) // grid: ok canvas coordinates from the workflow
            .zIndex(dragging ? 1 : 0)
            .gesture(DragGesture(minimumDistance: 2)
                .onChanged { value in
                    selected = object.uid
                    drag = (object.uid, value.translation)
                }
                .onEnded { value in
                    drag = nil
                    guard let from = WorkflowLayout.positions(workflow)[object.uid] else { return }
                    library.move(object.uid, to: WorkflowPoint(x: from.x + value.translation.width, y: from.y + value.translation.height),
                                 in: workflow, undo: undo)
                })
            .onTapGesture {
                selected = object.uid
                focused = true
            }
            .accessibilityAddTraits(selected == object.uid ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { selected = object.uid }
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

    /// S-063: a palette row dropped on the canvas; its card lands centered under the pointer.
    private func drop(_ types: [String], at location: CGPoint) -> Bool {
        guard let kind = types.first.flatMap(WorkflowPalette.kind) else { return false }
        let point = WorkflowPoint(x: location.x - Self.card.width / 2, y: location.y - Self.card.height / 2)
        library.add(kind, at: point, in: workflow, undo: undo)
        focused = true
        return true
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
