import ReachKit
import SwiftUI

/// S-062: the parts of the canvas that add, remove and change connections.
/// Drag from a card's output handle to another card; right-click a line for
/// Delete Connection and Modifier ▸; Edit Connections… (⌥⌘L) does both with the keyboard.
enum CanvasSpace {
    /// The coordinate space of the canvas's content, in the workflow's own points.
    static let name = "workflow-canvas"

    /// Where a line leaves a card, and where it enters one.
    static func output(_ point: WorkflowPoint) -> CGPoint {
        CGPoint(x: point.x + WorkflowCanvasView.card.width, y: point.y + WorkflowCanvasView.card.height / 2)
    }

    static func input(_ point: WorkflowPoint) -> CGPoint {
        CGPoint(x: point.x, y: point.y + WorkflowCanvasView.card.height / 2)
    }

    /// The card under `location`, other than `excluding`.
    static func object(at location: CGPoint, in positions: [String: WorkflowPoint], excluding: String) -> String? {
        let card = WorkflowCanvasView.card
        return positions.first { uid, point in
            uid != excluding && CGRect(x: point.x, y: point.y, width: card.width, height: card.height).contains(location)
        }?.key
    }
}

/// The curve from one card's right edge to the next card's left edge.
nonisolated struct ConnectionCurve: Shape {
    var from: CGPoint
    var to: CGPoint

    func path(in rect: CGRect) -> Path { Self.path(from: from, to: to) }

    static func path(from: CGPoint, to: CGPoint) -> Path {
        var path = Path()
        path.move(to: from)
        let bend = max(40, abs(to.x - from.x) / 2)
        path.addCurve(to: to, control1: CGPoint(x: from.x + bend, y: from.y), control2: CGPoint(x: to.x - bend, y: to.y))
        return path
    }
}

/// The modifiers a line can have, as the context menu lists them.
enum ConnectionModifier {
    static let all: [(title: String, flag: Int)] = [
        ("None", 0), ("⌘ Command", WorkflowConnection.command), ("⌥ Option", WorkflowConnection.option),
        ("⌃ Control", WorkflowConnection.control), ("⇧ Shift", WorkflowConnection.shift),
    ]

    static func name(_ flag: Int) -> String {
        all.first { $0.flag == flag }.map { $0.flag == 0 ? "no modifier" : String($0.title.dropFirst(2)) } ?? "a modifier"
    }
}

/// The round knob on a card's right edge that a new line is dragged from.
struct OutputHandle: View {
    let object: WorkflowObject
    let workflow: Workflow
    let positions: [String: WorkflowPoint]
    private var library = WorkflowLibrary.shared
    @Environment(\.undoManager) private var undo

    init(object: WorkflowObject, workflow: Workflow, positions: [String: WorkflowPoint]) {
        self.object = object
        self.workflow = workflow
        self.positions = positions
    }

    var body: some View {
        if !WorkflowEdit.ends.contains(object.type) {
            Circle()
                .fill(.background)
                .overlay(Circle().strokeBorder(ObjectCard.color(object.category), lineWidth: 2))
                .frame(width: Space.md, height: Space.md)
                .padding(Space.xs)
                .contentShape(Circle())
                .offset(x: Space.md / 2 + Space.xs) // grid: ok centred on the card's edge
                .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasSpace.name))
                    .onChanged { value in
                        let target = CanvasSpace.object(at: value.location, in: positions, excluding: object.uid)
                        library.connecting = WorkflowConnecting(
                            from: object.uid, point: value.location, target: target,
                            refusal: target.flatMap { WorkflowEdit.refusal(from: object.uid, to: $0, in: workflow)?.errorDescription })
                    }
                    .onEnded { _ in drop() })
                .help("Drag to another object to connect them")
                .accessibilityHidden(true)
        }
    }

    private func drop() {
        guard var connecting = library.connecting else { return }
        guard let target = connecting.target else {
            library.connecting = nil
            return
        }
        if connecting.refusal == nil,
           let refusal = library.connect(object.uid, to: target, in: workflow, undo: undo) {
            connecting.refusal = refusal.errorDescription
        }
        if connecting.refusal == nil {
            library.connecting = nil
        } else {
            connecting.dropped = true
            library.connecting = connecting
        }
    }
}

/// The line that follows the pointer while it is dragged, and the reason a card refuses it.
struct ConnectingLayer: View {
    let positions: [String: WorkflowPoint]
    private var library = WorkflowLibrary.shared

    init(positions: [String: WorkflowPoint]) {
        self.positions = positions
    }

    var body: some View {
        if let connecting = library.connecting, let start = positions[connecting.from] {
            ZStack(alignment: .topLeading) {
                if !connecting.dropped {
                    let refused = connecting.refusal != nil
                    ConnectionCurve(from: CanvasSpace.output(start), to: connecting.point)
                        .stroke(refused ? AnyShapeStyle(.secondary) : AnyShapeStyle(Palette.accent),
                                style: StrokeStyle(lineWidth: 2, dash: refused ? [Space.xs, Space.xs] : []))
                    Circle()
                        .fill(refused ? AnyShapeStyle(.secondary) : AnyShapeStyle(Palette.accent))
                        .frame(width: Space.sm, height: Space.sm)
                        .position(connecting.point) // grid: ok follows the pointer
                }
                if let refusal = connecting.refusal {
                    Label(refusal, systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, Space.xs)
                        .background(.background, in: Capsule())
                        .overlay(Capsule().strokeBorder(.separator))
                        .fixedSize()
                        .offset(x: connecting.point.x + Space.md, y: connecting.point.y + Space.md) // grid: ok next to the pointer
                        .accessibilityLabel(refusal)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// The invisible, wider band along a line that takes its right-click (S-062).
struct LineHit: View {
    let line: WorkflowLine
    let from: CGPoint
    let to: CGPoint
    let workflow: Workflow
    private var library = WorkflowLibrary.shared
    @Environment(\.undoManager) private var undo

    init(line: WorkflowLine, from: CGPoint, to: CGPoint, workflow: Workflow) {
        self.line = line
        self.from = from
        self.to = to
        self.workflow = workflow
    }

    var body: some View {
        Color.clear
            .contentShape(ConnectionCurve(from: from, to: to).stroke(lineWidth: Space.md))
            .contextMenu { ConnectionMenu(line: line, workflow: workflow, undo: undo) }
            .accessibilityElement()
            .accessibilityLabel("Connection from \(kind(line.from)) to \(kind(line.to)), \(ConnectionModifier.name(line.modifiers))")
            .accessibilityAction(named: "Delete Connection") { library.disconnect(line, in: workflow, undo: undo) }
            .accessibilityActions {
                ForEach(ConnectionModifier.all, id: \.flag) { modifier in
                    Button("Modifier \(modifier.flag == 0 ? "None" : String(modifier.title.dropFirst(2)))") {
                        library.setModifiers(modifier.flag, of: line, in: workflow, undo: undo)
                    }
                }
            }
    }

    private func kind(_ uid: String) -> String { workflow.object(uid)?.kindName ?? uid }
}

/// The context menu on a line: Delete Connection, and Modifier ▸ with a checkmark on the current key.
struct ConnectionMenu: View {
    let line: WorkflowLine
    let workflow: Workflow
    let undo: UndoManager?

    var body: some View {
        let library = WorkflowLibrary.shared
        Button("Delete Connection", role: .destructive) { library.disconnect(line, in: workflow, undo: undo) }
        Picker("Modifier", selection: Binding(get: { line.modifiers },
                                              set: { library.setModifiers($0, of: line, in: workflow, undo: undo) })) {
            ForEach(ConnectionModifier.all, id: \.flag) { Text($0.title).tag($0.flag) }
        }
        .pickerStyle(.menu)
    }
}

/// Edit Connections… (⌥⌘L): every other object, with a checkmark on the ones the
/// selected card connects to. Return or a double-click connects or disconnects one.
struct EditConnectionsPopover: View {
    let object: WorkflowObject
    let workflow: Workflow
    private var library = WorkflowLibrary.shared
    @Environment(\.undoManager) private var undo
    @State private var pick: String?

    init(object: WorkflowObject, workflow: Workflow) {
        self.object = object
        self.workflow = workflow
    }

    private var current: Workflow { library.workflow(workflow.id) ?? workflow }

    var body: some View {
        let others = current.objects.filter { $0.uid != object.uid }
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Connect \(object.kindName) To")
                .font(.headline)
            List(selection: $pick) {
                ForEach(others) { other in row(other).tag(other.uid) }
            }
            .contextMenu(forSelectionType: String.self, menu: { _ in }, primaryAction: { picked in
                picked.first.map(toggle)
            })
            .frame(width: 320, height: min(CGFloat(others.count) * 44 + Space.md, 360))
            Text("Return or a double-click connects or disconnects the selected object.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Space.lg)
        .gridArea("edit-connections", inset: Space.lg)
    }

    private func connected(_ uid: String) -> Bool {
        (current.connections[object.uid] ?? []).contains { $0.to == uid && $0.modifiers == 0 }
    }

    private func row(_ other: WorkflowObject) -> some View {
        let isConnected = connected(other.uid)
        let refusal = isConnected ? nil : WorkflowEdit.refusal(from: object.uid, to: other.uid, in: current)
        return HStack(spacing: Space.sm) {
            Image(systemName: "checkmark")
                .opacity(isConnected ? 1 : 0)
                .frame(width: Space.lg)
            VStack(alignment: .leading, spacing: 0) {
                Text(other.summary.isEmpty ? other.kindName : "\(other.kindName): \(other.summary)")
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let refusal {
                    Text(refusal.errorDescription ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(refusal == nil ? .primary : .secondary)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isConnected ? .isSelected : [])
    }

    private func toggle(_ uid: String) {
        if connected(uid) {
            library.disconnect(WorkflowLine(from: object.uid, to: uid), in: current, undo: undo)
        } else {
            library.connect(object.uid, to: uid, in: current, undo: undo)
        }
    }
}

/// VoiceOver on a card: Connect to and Disconnect from each other object.
struct ConnectionActions: ViewModifier {
    let object: WorkflowObject
    let workflow: Workflow
    @Environment(\.undoManager) private var undo

    func body(content: Content) -> some View {
        let library = WorkflowLibrary.shared
        let lines = workflow.connections[object.uid] ?? []
        content.accessibilityActions {
            ForEach(workflow.objects.filter { WorkflowEdit.refusal(from: object.uid, to: $0.uid, in: workflow) == nil }) { other in
                Button("Connect to \(other.kindName)") { library.connect(object.uid, to: other.uid, in: workflow, undo: undo) }
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Button("Disconnect from \(workflow.object(line.to)?.kindName ?? line.to)") {
                    library.disconnect(WorkflowLine(from: object.uid, to: line.to, modifiers: line.modifiers), in: workflow, undo: undo)
                }
            }
        }
    }
}
