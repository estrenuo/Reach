import Foundation
import ReachKit

extension SelfTest {
    /// S-065: select two cards, delete them, ⌘Z brings them back with their lines, ⌘⇧Z deletes them again.
    static func checkWorkflowDelete(model: AppModel) async {
        let library = WorkflowLibrary.shared
        let selection = library.selection
        library.addExample()
        guard let example = library.selected else {
            check("the delete check has a workflow to change", false, library.failure ?? "")
            return
        }
        defer {
            try? FileManager.default.removeItem(at: example.folder)
            library.reload()
            library.selection = selection
            library.selectedObjects = []
        }
        let undo = UndoManager()
        undo.groupsByEvent = false
        func reopened() -> Workflow? { Workflow(folder: example.folder) }
        func lines(_ workflow: Workflow?) -> [String] { workflow?.connections["HELLO"]?.map(\.to) ?? [] }

        // A click on Copy, then ⌘-click on Open URL: both are selected; ⌘-click again takes one out.
        library.select("COPY")
        library.select("WEB", command: true)
        check("⌘-click adds a card to the selection", library.selectedObjects == ["COPY", "WEB"])
        check("with two selected, the arrow keys move none", library.selectedObject == nil)
        library.select("HELLO", shift: true)
        library.select("HELLO", command: true)
        check("⇧-click adds, ⌘-click on a selected card takes it out", library.selectedObjects == ["COPY", "WEB"])

        undo.beginUndoGrouping()
        library.delete(library.selectedObjects, in: library.workflow(example.id) ?? example, undo: undo)
        undo.endUndoGrouping()
        let deleted = reopened()
        check("Delete removes both objects", deleted?.objects.map(\.uid) == ["HELLO"], "\(deleted?.objects.map(\.uid) ?? [])")
        check("and their lines", lines(deleted).isEmpty)
        check("and their place on the canvas", deleted?.positions["COPY"] == nil && deleted?.positions["WEB"] == nil)
        check("the canvas shows the workflow without them", library.workflow(example.id)?.objects.count == 1)
        check("the selection is empty after the delete", library.selectedObjects.isEmpty)
        check("Undo is named Delete 2 Objects", undo.undoActionName == "Delete 2 Objects", undo.undoActionName)

        undo.undo()
        let back = reopened()
        check("⌘Z brings both back", back?.objects.map(\.uid) == ["HELLO", "COPY", "WEB"], "\(back?.objects.map(\.uid) ?? [])")
        check("with their lines, in their order", lines(back) == ["COPY", "WEB"])
        check("the ⌘ line keeps its key", back?.connections["HELLO"]?.last?.modifiers == WorkflowConnection.command)
        check("and in their places", back?.positions["COPY"] == WorkflowPoint(x: 300, y: 20) && back?.positions["WEB"] == WorkflowPoint(x: 300, y: 160))
        check("the restored cards are selected", library.selectedObjects == ["COPY", "WEB"])

        undo.redo()
        check("⌘⇧Z deletes them again", reopened()?.objects.map(\.uid) == ["HELLO"] && lines(reopened()).isEmpty)
        undo.undo()

        // One card: the undo name has no number.
        library.select("WEB")
        undo.beginUndoGrouping()
        library.delete(library.selectedObjects, in: library.workflow(example.id) ?? example, undo: undo)
        undo.endUndoGrouping()
        check("deleting one card is named Delete Object", undo.undoActionName == "Delete Object", undo.undoActionName)
        check("it leaves the other line", lines(reopened()) == ["COPY"])
    }
}
