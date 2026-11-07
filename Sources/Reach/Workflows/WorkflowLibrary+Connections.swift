import Foundation
import ReachKit

/// A line being dragged from a card's output handle (S-062), in canvas points.
struct WorkflowConnecting: Equatable {
    var from: String
    var point: CGPoint
    /// The card under the pointer, and why it cannot take the line.
    var target: String?
    var refusal: String?
    /// Released somewhere that refused it: only the reason stays, next to the drop.
    var dropped = false
}

/// S-062: connect, disconnect and change a line's modifier, each saved at
/// once in info.plist and undone with ⌘Z. A workflow changed on disk since
/// it was read is read again first, as in S-061.
extension WorkflowLibrary {
    /// Adds a line from `from` to `to`. Returns the reason when the line is refused; nothing is written then.
    @discardableResult
    func connect(_ from: String, to: String, in workflow: Workflow, undo: UndoManager?) -> WorkflowRefusal? {
        let current = fresh(workflow)
        if let refusal = WorkflowEdit.refusal(from: from, to: to, in: current) { return refusal }
        do {
            try WorkflowEdit.connect(from, to: to, folder: current.folder)
        } catch let refusal as WorkflowRefusal {
            return refusal
        } catch {
            failed("connect the objects", in: current, error)
            return nil
        }
        reload()
        let line = WorkflowLine(from: from, to: to)
        let id = workflow.id
        undo?.registerUndo(withTarget: self) { library in
            MainActor.assumeIsolated {
                if let workflow = library.workflow(id) { library.disconnect(line, in: workflow, undo: undo, name: "Connect Objects") }
            }
        }
        undo?.setActionName("Connect Objects")
        return nil
    }

    /// Removes `line`. ⌘Z puts it back where it was, with every key it had.
    func disconnect(_ line: WorkflowLine, in workflow: Workflow, undo: UndoManager?, name: String = "Delete Connection") {
        let current = fresh(workflow)
        let removed: (index: Int, entry: [String: Any])?
        do {
            removed = try WorkflowEdit.disconnect(line, folder: current.folder)
        } catch {
            failed("delete the connection", in: current, error)
            return
        }
        reload()
        guard let removed else { return }
        let id = workflow.id
        let entry = PlistBox(removed.entry)
        undo?.registerUndo(withTarget: self) { library in
            MainActor.assumeIsolated {
                if let workflow = library.workflow(id) {
                    library.restore(entry.value, as: line, at: removed.index, in: workflow, undo: undo, name: name)
                }
            }
        }
        undo?.setActionName(name)
    }

    /// Puts a removed line back: the undo of Delete Connection, or the redo of Connect Objects.
    private func restore(_ entry: [String: Any], as line: WorkflowLine, at index: Int, in workflow: Workflow,
                         undo: UndoManager?, name: String) {
        let current = fresh(workflow)
        do {
            try WorkflowEdit.insert(entry, from: line.from, at: index, folder: current.folder)
        } catch {
            failed("connect the objects", in: current, error)
            return
        }
        reload()
        let id = workflow.id
        undo?.registerUndo(withTarget: self) { library in
            MainActor.assumeIsolated {
                if let workflow = library.workflow(id) { library.disconnect(line, in: workflow, undo: undo, name: name) }
            }
        }
        undo?.setActionName(name)
    }

    /// Sets the key held with Return for `line`: 0 for none, or one of `WorkflowConnection`'s flags.
    func setModifiers(_ modifiers: Int, of line: WorkflowLine, in workflow: Workflow, undo: UndoManager?) {
        guard modifiers != line.modifiers else { return }
        let current = fresh(workflow)
        let moved: WorkflowLine?
        do {
            moved = try WorkflowEdit.setModifiers(modifiers, of: line, folder: current.folder)
        } catch {
            failed("change the modifier", in: current, error)
            return
        }
        reload()
        guard let moved else {
            failure = "Unable to change the modifier in “\(current.name)”: another line to the same object already uses that key."
            return
        }
        let id = workflow.id
        undo?.registerUndo(withTarget: self) { library in
            MainActor.assumeIsolated {
                if let workflow = library.workflow(id) { library.setModifiers(line.modifiers, of: moved, in: workflow, undo: undo) }
            }
        }
        undo?.setActionName("Change Modifier")
    }

    /// The workflow as it is on disk now.
    private func fresh(_ workflow: Workflow) -> Workflow {
        failure = nil
        if WorkflowEdit.changedOnDisk(workflow) { reload() }
        return self.workflow(workflow.id) ?? workflow
    }

    private func failed(_ what: String, in workflow: Workflow, _ error: Error) {
        failure = "Unable to \(what) in “\(workflow.name)”: \(error.localizedDescription)"
        reload()
    }
}

/// A line's plist entry, carried into an undo closure.
private final class PlistBox: @unchecked Sendable {
    let value: [String: Any]
    init(_ value: [String: Any]) { self.value = value }
}
