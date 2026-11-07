import Foundation

/// Changes made on the canvas (M8). Each one edits only its own keys in
/// info.plist, so the rest of the file stays as Alfred wrote it.
public enum WorkflowEdit {
    /// The step cards snap to when they are dropped or moved with the arrow keys.
    public static let grid = 10.0

    /// `point` on the grid, never left of or above the canvas.
    public static func snapped(_ point: WorkflowPoint) -> WorkflowPoint {
        func snap(_ value: Double) -> Double { max(0, (value / grid).rounded() * grid) }
        return WorkflowPoint(x: snap(point.x), y: snap(point.y))
    }

    /// Puts object `uid` at `point` (snapped) in uidata; other keys of its uidata, like its note, stay.
    public static func move(_ uid: String, to point: WorkflowPoint, in plist: inout [String: Any]) {
        let point = snapped(point)
        var uidata = plist["uidata"] as? [String: Any] ?? [:]
        var entry = uidata[uid] as? [String: Any] ?? [:]
        entry["xpos"] = point.x
        entry["ypos"] = point.y
        uidata[uid] = entry
        plist["uidata"] = uidata
    }

    /// Moves object `uid` in the workflow in `folder`, reading info.plist fresh,
    /// so a change made elsewhere since the canvas read it is kept.
    public static func move(_ uid: String, to point: WorkflowPoint, folder: URL) throws {
        try WorkflowFolder.update(folder) { move(uid, to: point, in: &$0) }
    }

    /// When info.plist in `folder` was last changed.
    public static func modified(_ folder: URL) -> Date? {
        (try? folder.appending(path: Workflow.infoFile).resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    /// True when info.plist changed on disk after `workflow` was read.
    public static func changedOnDisk(_ workflow: Workflow) -> Bool {
        modified(workflow.folder) != workflow.modified
    }
}
