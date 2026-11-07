import Foundation
import ReachKit

extension SelfTest {
    /// S-064: Configure Object… changes a Keyword and an Open URL; the launcher
    /// follows the new settings at once, and ⌘Z puts the old ones back.
    static func checkWorkflowObject(model: AppModel) async {
        let library = WorkflowLibrary.shared
        let lm = model.launcherModel
        let selection = library.selection
        library.addExample()
        guard let example = library.selected,
              let keyword = WorkflowPalette.kind(KeywordInput.type), let openURL = WorkflowPalette.kind(Workflow.openURL) else {
            check("Configure Object… has a workflow to change", false, library.failure ?? "")
            return
        }
        let realOpener = lm.opener
        var opened: [URL] = []
        lm.opener = { opened.append($0); return true }
        defer {
            lm.opener = realOpener
            model.launcher?.hide()
            try? FileManager.default.removeItem(at: example.folder)
            library.selectedObjects = []
            library.configuringObject = nil
            library.reload()
            library.selection = selection
        }
        let undo = UndoManager()
        undo.groupsByEvent = false
        func current() -> Workflow { library.workflow(example.id) ?? example }
        func step(_ change: () -> Void) {
            undo.beginUndoGrouping()
            change()
            undo.endUndoGrouping()
        }
        library.add(keyword, at: WorkflowPoint(x: 40, y: 260), in: current(), undo: nil, uid: "CFGKEYWORD")
        library.add(openURL, at: WorkflowPoint(x: 300, y: 260), in: current(), undo: nil, uid: "CFGURL")
        try? WorkflowFolder.update(example.folder) { plist in
            var connections = plist["connections"] as? [String: Any] ?? [:]
            connections["CFGKEYWORD"] = [["destinationuid": "CFGURL", "modifiers": 0, "modifiersubtext": "", "vitoclose": false]]
            plist["connections"] = connections
        }
        library.reload()

        // The sheet opens for one selected card whose kind has a form.
        library.select("CFGURL")
        library.configureObject()
        check("Configure Object… opens for the selected card", library.configuringObject?.uid == "CFGURL")
        library.configuringObject = nil
        library.configureObject("COPY")
        check("and for a double-clicked card", library.configuringObject?.uid == "COPY")
        library.configuringObject = nil

        // What Save in the two sheets does.
        step {
            library.configure("CFGKEYWORD", values: WorkflowForm.values(current().object("CFGKEYWORD")!)
                .merging(["keyword": .string("rcfg"), "text": .string("Open {query}")]) { $1 }, in: current(), undo: undo)
        }
        step {
            library.configure("CFGURL", values: WorkflowForm.values(current().object("CFGURL")!)
                .merging(["url": .string("https://old.example/?q={query}")]) { $1 }, in: current(), undo: undo)
        }
        step {
            library.configure("CFGURL", values: WorkflowForm.values(current().object("CFGURL")!)
                .merging(["url": .string("https://new.example/?q={query}")]) { $1 }, in: current(), undo: undo)
        }
        check("Save writes the new address into info.plist",
              Workflow(folder: example.folder)?.object("CFGURL")?.string("url") == "https://new.example/?q={query}")
        check("Undo is named Configure Object", undo.undoActionName == "Configure Object")

        guard let launcher = model.launcher else { return }
        func run() async -> String? {
            opened = []
            await showAgain(launcher)
            lm.query = "rcfg reach"
            try? await Task.sleep(for: .milliseconds(300))
            guard lm.results.contains(where: { $0.title == "Open reach" }) else { return "no row: " + lm.results.map(\.title).joined(separator: ", ") }
            lm.openSelected()
            try? await Task.sleep(for: .milliseconds(200))
            return opened.last?.absoluteString
        }
        let first = await run()
        check("↩ in the launcher opens the new address", first == "https://new.example/?q=reach", first ?? "nothing opened")
        undo.undo()
        let second = await run()
        check("⌘Z puts the old address back", second == "https://old.example/?q=reach", second ?? "nothing opened")
        undo.redo()
        check("⌘⇧Z the new one", Workflow(folder: example.folder)?.object("CFGURL")?.string("url") == "https://new.example/?q={query}")
    }
}
