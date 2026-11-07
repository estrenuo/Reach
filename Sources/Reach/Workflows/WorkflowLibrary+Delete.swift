import Foundation
import ReachKit

extension WorkflowLibrary {
    /// S-065: removes objects and every line to or from them, and saves at once.
    /// A workflow changed on disk since it was read is read again first.
    /// ⌘Z puts them back with their lines, ⌘⇧Z deletes them again.
    func delete(_ uids: Set<String>, in workflow: Workflow, undo: UndoManager?) {
        failure = nil
        if WorkflowEdit.changedOnDisk(workflow) { reload() }
        let current = self.workflow(workflow.id) ?? workflow
        let present = uids.intersection(current.objects.map(\.uid))
        guard !present.isEmpty else { return }
        let removed: DeletedObjects
        do {
            removed = try WorkflowEdit.delete(present, folder: current.folder)
        } catch {
            failure = "Unable to delete the objects in “\(current.name)”: \(error.localizedDescription)"
            reload()
            return
        }
        selectedObjects.subtract(present)
        reload()
        let id = workflow.id
        undo?.registerUndo(withTarget: self) { library in
            MainActor.assumeIsolated {
                if let workflow = library.workflow(id) { library.restore(removed, in: workflow, undo: undo) }
            }
        }
        undo?.setActionName(WorkflowEdit.deleteName(present.count))
    }

    /// Puts deleted objects back (the undo of `delete`) and selects them.
    func restore(_ removed: DeletedObjects, in workflow: Workflow, undo: UndoManager?) {
        failure = nil
        if WorkflowEdit.changedOnDisk(workflow) { reload() }
        let current = self.workflow(workflow.id) ?? workflow
        do {
            try WorkflowEdit.restore(removed, folder: current.folder)
        } catch {
            failure = "Unable to put the objects back in “\(current.name)”: \(error.localizedDescription)"
            reload()
            return
        }
        reload()
        let uids = Set(removed.uids)
        selectedObjects = uids
        let id = workflow.id
        undo?.registerUndo(withTarget: self) { library in
            MainActor.assumeIsolated {
                if let workflow = library.workflow(id) { library.delete(uids, in: workflow, undo: undo) }
            }
        }
        undo?.setActionName(WorkflowEdit.deleteName(uids.count))
    }

    /// The single selected object, which the arrow keys move (S-061).
    var selectedObject: String? {
        selectedObjects.count == 1 ? selectedObjects.first : nil
    }

    /// A click on a card (S-065): ⌘ adds or removes it, ⇧ adds it, a plain click selects only it.
    func select(_ uid: String, command: Bool = false, shift: Bool = false) {
        if command {
            if selectedObjects.contains(uid) { selectedObjects.remove(uid) } else { selectedObjects.insert(uid) }
        } else if shift {
            selectedObjects.insert(uid)
        } else {
            selectedObjects = [uid]
        }
    }
}
