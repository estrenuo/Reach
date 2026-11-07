import Foundation
import ReachKit

/// S-063: whether the palette shows beside the canvas, and what its search field holds.
@Observable
final class WorkflowPaletteState {
    static let shared = WorkflowPaletteState()

    var shown = false
    /// The text in Search Objects.
    var filter = ""
    /// The categories opened by hand; with a filter every category with a match is open.
    var expanded: Set<WorkflowCategory> = []
    /// Set by Search Palette (⌘/ or `/` on the canvas); the palette puts the
    /// cursor in its search field and clears it.
    var wantsSearch = false

    private init() {}

    /// Opens the palette and puts the cursor in its search field.
    func search() {
        shown = true
        wantsSearch = true
    }
}

extension WorkflowLibrary {
    /// S-063: adds an object of `kind` to `workflow` at `point`, or at a free
    /// place when `point` is nil, saves it at once and selects the new card.
    /// ⌘Z takes it off again, ⌘⇧Z puts it back with the same uid.
    func add(_ kind: WorkflowKind, at point: WorkflowPoint?, in workflow: Workflow, undo: UndoManager?,
             uid: String = WorkflowEdit.newUID()) {
        failure = nil
        if WorkflowEdit.changedOnDisk(workflow) { reload() }
        let current = self.workflow(workflow.id) ?? workflow
        let place = point.map(WorkflowEdit.snapped) ?? WorkflowEdit.freePlace(in: current, after: selectedObject)
        do {
            try WorkflowEdit.add(kind, uid: uid, at: place, folder: current.folder)
        } catch {
            failure = "Unable to add the object to “\(current.name)”: \(error.localizedDescription)"
            reload()
            return
        }
        reload()
        selectedObject = uid
        let id = workflow.id
        undo?.registerUndo(withTarget: self) { library in
            MainActor.assumeIsolated {
                if let workflow = library.workflow(id) { library.removeAdded(uid, kind: kind, at: place, in: workflow, undo: undo) }
            }
        }
        undo?.setActionName("Add Object")
    }

    /// Undo Add Object: takes the object off; Redo adds it again where it was.
    private func removeAdded(_ uid: String, kind: WorkflowKind, at place: WorkflowPoint, in workflow: Workflow, undo: UndoManager?) {
        failure = nil
        if WorkflowEdit.changedOnDisk(workflow) { reload() }
        let current = self.workflow(workflow.id) ?? workflow
        do {
            try WorkflowEdit.removeAdded(uid, folder: current.folder)
        } catch {
            failure = "Unable to change “\(current.name)”: \(error.localizedDescription)"
        }
        reload()
        if selectedObject == uid { selectedObject = nil }
        let id = workflow.id
        undo?.registerUndo(withTarget: self) { library in
            MainActor.assumeIsolated {
                if let workflow = library.workflow(id) { library.add(kind, at: place, in: workflow, undo: undo, uid: uid) }
            }
        }
        undo?.setActionName("Add Object")
    }
}
