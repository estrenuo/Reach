import Foundation
import ReachKit

/// The object in the Configure Object… sheet (S-064).
struct ObjectInSheet: Identifiable, Equatable {
    var workflow: String
    var uid: String
    var id: String { workflow + "/" + uid }
}

extension WorkflowLibrary {
    /// True when the sheet has fields for this object's kind.
    static func canConfigure(_ object: WorkflowObject) -> Bool { !WorkflowForm.fields(object.type).isEmpty }

    /// Opens Configure Object… for `uid`, or for the one selected card.
    func configureObject(_ uid: String? = nil) {
        guard let workflow = selected, let uid = uid ?? (selectedObjects.count == 1 ? selectedObject : nil),
              let object = workflow.object(uid), Self.canConfigure(object) else { return }
        configuringObject = ObjectInSheet(workflow: workflow.id, uid: uid)
    }

    /// S-064: saves the settings of object `uid`; keys the sheet does not show stay.
    /// ⌘Z puts its whole old config back, ⌘⇧Z the new one.
    func configure(_ uid: String, values: [String: PlistValue], in workflow: Workflow, undo: UndoManager?) {
        failure = nil
        if WorkflowEdit.changedOnDisk(workflow) { reload() }
        let current = self.workflow(workflow.id) ?? workflow
        var old: [String: Any]?
        do {
            try WorkflowFolder.update(current.folder) { plist in
                old = WorkflowEdit.config(uid, in: plist)
                WorkflowEdit.configure(uid, values: values, in: &plist)
            }
        } catch {
            failure = "Unable to save the object in “\(current.name)”: \(error.localizedDescription)"
            reload()
            return
        }
        reload()
        registerConfigUndo(uid, back: old ?? [:], in: workflow.id, undo: undo)
    }

    private func restoreConfig(_ uid: String, _ config: [String: Any], in id: String, undo: UndoManager?) {
        guard let workflow = workflow(id) else { return }
        var replaced: [String: Any]?
        do {
            try WorkflowFolder.update(workflow.folder) { plist in
                replaced = WorkflowEdit.config(uid, in: plist)
                WorkflowEdit.setConfig(uid, config, in: &plist)
            }
        } catch {
            failure = "Unable to save the object in “\(workflow.name)”: \(error.localizedDescription)"
        }
        reload()
        registerConfigUndo(uid, back: replaced ?? [:], in: id, undo: undo)
    }

    private func registerConfigUndo(_ uid: String, back config: [String: Any], in id: String, undo: UndoManager?) {
        let kept = WorkflowConfigBox(config)
        undo?.registerUndo(withTarget: self) { library in
            MainActor.assumeIsolated { library.restoreConfig(uid, kept.config, in: id, undo: undo) }
        }
        undo?.setActionName("Configure Object")
    }
}

/// A config kept for Undo; plist values are immutable here.
private final class WorkflowConfigBox: @unchecked Sendable {
    let config: [String: Any]
    init(_ config: [String: Any]) { self.config = config }
}
