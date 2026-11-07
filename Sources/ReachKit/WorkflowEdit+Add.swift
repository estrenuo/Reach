import Foundation

/// S-063: adding an object from the palette. Like a move, an add edits only
/// `objects` and the new object's `uidata`; the rest of info.plist stays.
extension WorkflowEdit {
    /// A fresh object uid in Alfred's style: an uppercase UUID.
    public static func newUID() -> String { UUID().uuidString.uppercased() }

    /// Appends a new object of `kind` with its default config and puts its card at `point` (snapped).
    public static func add(_ kind: WorkflowKind, uid: String, at point: WorkflowPoint, in plist: inout [String: Any]) {
        var objects = plist["objects"] as? [[String: Any]] ?? []
        objects.append(kind.plist(uid: uid))
        plist["objects"] = objects
        move(uid, to: point, in: &plist)
    }

    public static func add(_ kind: WorkflowKind, uid: String, at point: WorkflowPoint, folder: URL) throws {
        try WorkflowFolder.update(folder) { add(kind, uid: uid, at: point, in: &$0) }
    }

    /// Takes an added object off again (Undo Add Object): the object, its
    /// uidata, and any line to or from it. Nothing else changes.
    public static func removeAdded(_ uid: String, in plist: inout [String: Any]) {
        if let objects = plist["objects"] as? [[String: Any]] {
            plist["objects"] = objects.filter { $0["uid"] as? String != uid }
        }
        if var uidata = plist["uidata"] as? [String: Any] {
            uidata[uid] = nil
            plist["uidata"] = uidata
        }
        if var connections = plist["connections"] as? [String: Any] {
            connections[uid] = nil
            for (from, lines) in connections {
                guard let lines = lines as? [[String: Any]] else { continue }
                let kept = lines.filter { $0["destinationuid"] as? String != uid }
                if kept.count != lines.count { connections[from] = kept }
            }
            plist["connections"] = connections
        }
    }

    public static func removeAdded(_ uid: String, folder: URL) throws {
        try WorkflowFolder.update(folder) { removeAdded(uid, in: &$0) }
    }

    /// Where Return in the palette puts a new card: right of the selected card,
    /// else below the lowest card, moved down a row at a time until it covers no card.
    public static func freePlace(in workflow: Workflow, after selected: String? = nil) -> WorkflowPoint {
        let positions = WorkflowLayout.positions(workflow)
        var point: WorkflowPoint
        if let selected, let from = positions[selected] {
            point = WorkflowPoint(x: from.x + WorkflowLayout.column, y: from.y)
        } else if let lowest = positions.values.map(\.y).max() {
            point = WorkflowPoint(x: positions.values.map(\.x).min() ?? 40, y: lowest + WorkflowLayout.row)
        } else {
            point = WorkflowPoint(x: 40, y: 40)
        }
        point = snapped(point)
        // A card covers another when they are closer than a column across and a row down.
        func covers(_ other: WorkflowPoint) -> Bool {
            abs(other.x - point.x) < WorkflowLayout.column - 20 && abs(other.y - point.y) < WorkflowLayout.row - 20
        }
        while positions.values.contains(where: covers) { point.y += WorkflowLayout.row }
        return point
    }
}
