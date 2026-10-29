import ReachKit
import SwiftUI

/// A workflow's objects and the lines between them (S-044), where its
/// uidata puts them. Read only: the canvas shows how a workflow is built.
struct WorkflowCanvasView: View {
    let workflow: Workflow

    static let card = CGSize(width: 168, height: 56)

    var body: some View {
        if workflow.objects.isEmpty {
            ContentUnavailableView("No Objects", systemImage: "square.dashed",
                                   description: Text("This workflow has nothing on its canvas."))
        } else {
            let positions = WorkflowLayout.positions(workflow)
            let size = canvasSize(positions)
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    Lines(workflow: workflow, positions: positions)
                    ForEach(workflow.objects) { object in
                        if let point = positions[object.uid] {
                            ObjectCard(object: object)
                                .frame(width: Self.card.width, height: Self.card.height)
                                .offset(x: point.x, y: point.y) // grid: ok canvas coordinates from the workflow
                        }
                    }
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
            }
            .defaultScrollAnchor(.topLeading)
            .accessibilityLabel("Canvas of \(workflow.name)")
        }
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
private struct ObjectCard: View {
    let object: WorkflowObject

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
