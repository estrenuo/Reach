import Foundation
import ReachKit

extension SelfTest {
    /// S-062: connect a Keyword to Copy to Clipboard on the canvas, run it from
    /// the launcher, disconnect it, run it again. ⌘Z undoes each change.
    static func checkWorkflowConnections(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let library = WorkflowLibrary.shared
        let folder = library.folder.appending(path: "selftest-connect.workflow", directoryHint: .isDirectory)
        let plist: [String: Any] = [
            "bundleid": "com.reach.selftest.connect", "name": "Connect Test", "createdby": "Reach",
            "objects": [
                ["uid": "KW", "type": KeywordInput.type, "config": ["keyword": "rconnect", "argumenttype": 2, "text": "Connect Test"]],
                ["uid": "COPY", "type": Workflow.copyToClipboard, "config": ["clipboardtext": "connected"]],
            ],
            "uidata": ["KW": ["xpos": 40, "ypos": 40], "COPY": ["xpos": 300, "ypos": 40]],
        ]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? data.write(to: folder.appending(path: Workflow.infoFile))
        }
        library.reload()
        let copier = lm.copier
        var copied: [String] = []
        lm.copier = { copied.append($0) }
        defer {
            lm.copier = copier
            launcher.hide()
            try? FileManager.default.removeItem(at: folder)
            library.reload()
        }
        let id = folder.lastPathComponent
        guard library.workflow(id) != nil else {
            check("the connect workflow is read", false)
            return
        }
        let undo = UndoManager()
        undo.groupsByEvent = false
        func step(_ change: (Workflow) -> Void) {
            guard let workflow = library.workflow(id) else { return }
            undo.beginUndoGrouping()
            change(workflow)
            undo.endUndoGrouping()
        }
        func lines() -> [WorkflowConnection] { Workflow(folder: folder)?.connections["KW"] ?? [] }
        /// Types the keyword and presses Return, as a person would; what it copied.
        func run() async -> [String] {
            copied = []
            launcher.show()
            lm.query = "rconnect"
            try? await Task.sleep(for: .milliseconds(80))
            lm.openSelected()
            try? await Task.sleep(for: .milliseconds(80))
            return copied
        }

        // Kinds that cannot connect are refused with the reason, and nothing is written.
        let refused = library.workflow(id).flatMap { library.connect("COPY", to: "KW", in: $0, undo: undo) }
        check("a line out of Copy to Clipboard is refused with the reason",
              refused?.errorDescription == "Copy to Clipboard ends a workflow: nothing comes after it." && lines().isEmpty,
              refused?.errorDescription ?? "not refused")

        step { _ = library.connect("KW", to: "COPY", in: $0, undo: undo) }
        let line = lines().first
        check("a new connection is saved at once, without a modifier", lines().count == 1 && line?.to == "COPY" && line?.modifiers == 0,
              "\(lines())")
        check("Undo is named Connect Objects", undo.undoActionName == "Connect Objects")
        check("↩ on the keyword runs the new line at once", await run() == ["connected"], "\(copied)")
        undo.undo()
        check("⌘Z removes the new connection", lines().isEmpty)
        undo.redo()
        check("⌘⇧Z draws it again", lines().map(\.to) == ["COPY"])

        // The modifier from the line's context menu: plain ↩ no longer takes the line.
        step { library.setModifiers(WorkflowConnection.command, of: WorkflowLine(from: "KW", to: "COPY"), in: $0, undo: undo) }
        check("Modifier ▸ ⌘ Command sets the line's key", lines().first?.modifiers == WorkflowConnection.command)
        check("Undo is named Change Modifier", undo.undoActionName == "Change Modifier")
        undo.undo()
        check("⌘Z sets the key back", lines().first?.modifiers == 0)

        step { library.disconnect(WorkflowLine(from: "KW", to: "COPY"), in: $0, undo: undo) }
        check("Delete Connection removes the line", lines().isEmpty)
        check("Undo is named Delete Connection", undo.undoActionName == "Delete Connection")
        check("the second run copies nothing", await run().isEmpty, "\(copied)")
        undo.undo()
        check("⌘Z brings the connection back", lines().map(\.to) == ["COPY"])
        check("and ↩ copies again", await run() == ["connected"], "\(copied)")
        undo.redo()
        check("⌘⇧Z deletes it again", lines().isEmpty)
    }
}
