import Foundation
import ReachKit

extension SelfTest {
    /// M8: the workflow editor changes Alfred's info.plist. S-061 moves a card.
    static func checkWorkflowEditor(model: AppModel) async {
        let library = WorkflowLibrary.shared
        let selection = library.selection
        library.addExample()
        guard let example = library.selected else {
            check("the editor has a workflow to change", false, library.failure ?? "")
            return
        }
        defer {
            try? FileManager.default.removeItem(at: example.folder)
            library.reload()
            library.selection = selection
        }
        let undo = UndoManager()
        undo.groupsByEvent = false
        func moved(_ to: WorkflowPoint) {
            undo.beginUndoGrouping()
            library.move("HELLO", to: to, in: library.workflow(example.id) ?? example, undo: undo)
            undo.endUndoGrouping()
        }
        func reopened() -> WorkflowPoint? { Workflow(folder: example.folder)?.positions["HELLO"] }

        // The drop the canvas makes when a card is dragged 163 to the right and 57 down.
        moved(WorkflowPoint(x: 40 + 163, y: 80 + 57))
        check("a dragged card stays where it was dropped, on the grid", reopened() == WorkflowPoint(x: 200, y: 140),
              "\(String(describing: reopened()))")
        check("the canvas shows it there", library.workflow(example.id).map { WorkflowLayout.positions($0)["HELLO"] } == WorkflowPoint(x: 200, y: 140))
        check("the other cards stay put", Workflow(folder: example.folder)?.positions["COPY"] == WorkflowPoint(x: 300, y: 20))
        check("Undo is named Move Object", undo.undoActionName == "Move Object")
        undo.undo()
        check("⌘Z puts it back", reopened() == WorkflowPoint(x: 40, y: 80))
        undo.redo()
        check("⌘⇧Z moves it again", reopened() == WorkflowPoint(x: 200, y: 140))

        // Alfred changes the workflow after Reach read it: the move keeps that change.
        let stale = library.workflow(example.id) ?? example
        try? await Task.sleep(for: .milliseconds(1100))
        try? WorkflowFolder.update(example.folder) { $0["name"] = "Changed in Alfred" }
        library.move("HELLO", to: WorkflowPoint(x: 0, y: 0), in: stale, undo: nil)
        let now = Workflow(folder: example.folder)
        check("a change made on disk since reading is kept", now?.name == "Changed in Alfred" && now?.positions["HELLO"] == WorkflowPoint(x: 0, y: 0))
        check("and the canvas shows the workflow as it is now", library.workflow(example.id)?.name == "Changed in Alfred")
    }
}
