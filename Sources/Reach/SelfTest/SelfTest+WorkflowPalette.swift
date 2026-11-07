import Foundation
import ReachKit

extension SelfTest {
    /// S-063: add a Keyword input and an Open URL from the palette, connect
    /// them, set the keyword: the launcher shows its row and ↩ opens the URL.
    static func checkWorkflowPalette(model: AppModel) async {
        let library = WorkflowLibrary.shared
        let lm = model.launcherModel
        let selection = library.selection
        library.addExample()
        guard let example = library.selected,
              let keyword = WorkflowPalette.kind(KeywordInput.type), let openURL = WorkflowPalette.kind(Workflow.openURL) else {
            check("the palette has a workflow to add to", false, library.failure ?? "")
            return
        }
        let realOpener = lm.opener
        var opened: [URL] = []
        lm.opener = { opened.append($0); return true }
        defer {
            lm.opener = realOpener
            model.launcher?.hide()
            try? FileManager.default.removeItem(at: example.folder)
            library.selectedObject = nil
            library.reload()
            library.selection = selection
        }
        let undo = UndoManager()
        undo.groupsByEvent = false
        func added(_ kind: WorkflowKind, at point: WorkflowPoint?) -> String? {
            let before = Set((library.workflow(example.id) ?? example).objects.map(\.uid))
            undo.beginUndoGrouping()
            library.add(kind, at: point, in: library.workflow(example.id) ?? example, undo: undo)
            undo.endUndoGrouping()
            return Workflow(folder: example.folder)?.objects.map(\.uid).first { !before.contains($0) }
        }

        // Return in the palette: no point, so a free place.
        library.selectedObject = nil
        guard let kw = added(keyword, at: nil) else {
            check("Return on Keyword adds a Keyword input", false, library.failure ?? "nothing added")
            return
        }
        var now = Workflow(folder: example.folder)
        check("Return on Keyword adds a Keyword input with a fresh uppercase uid",
              now?.object(kw)?.type == KeywordInput.type && UUID(uuidString: kw) != nil && kw == kw.uppercased())
        check("it sits in a free place below the others", now?.positions[kw] == WorkflowPoint(x: 40, y: 260),
              "\(String(describing: now?.positions[kw]))")
        check("the new card is selected, so the arrow keys move it", library.selectedObject == kw)
        check("Undo is named Add Object", undo.undoActionName == "Add Object")
        undo.undo()
        check("⌘Z takes it off the canvas", Workflow(folder: example.folder)?.object(kw) == nil
              && Workflow(folder: example.folder)?.positions[kw] == nil)
        undo.redo()
        now = Workflow(folder: example.folder)
        check("⌘⇧Z puts it back with the same uid and place", now?.object(kw)?.type == KeywordInput.type
              && now?.positions[kw] == WorkflowPoint(x: 40, y: 260))

        // A drop: the card lands where it was dropped, on the grid.
        guard let url = added(openURL, at: WorkflowPoint(x: 263, y: 247)) else {
            check("a dropped Open URL is added", false, library.failure ?? "nothing added")
            return
        }
        now = Workflow(folder: example.folder)
        check("a dropped Open URL lands where it was dropped, on the grid", now?.positions[url] == WorkflowPoint(x: 260, y: 250))
        check("Alfred's version is written with it", {
            let data = try? Data(contentsOf: example.folder.appending(path: Workflow.infoFile))
            let plist = data.flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
            let objects = plist?["objects"] as? [[String: Any]] ?? []
            return objects.first { $0["uid"] as? String == url }?["version"] as? Int == 1
                && objects.first { $0["uid"] as? String == kw }?["version"] as? Int == 1
        }())

        // Connect them and set the keyword and URL (S-062 and S-064 build the UI for these).
        try? WorkflowFolder.update(example.folder) { plist in
            var connections = plist["connections"] as? [String: Any] ?? [:]
            connections[kw] = [["destinationuid": url, "modifiers": 0, "modifiersubtext": "", "vitoclose": false]]
            plist["connections"] = connections
            plist["objects"] = (plist["objects"] as? [[String: Any]] ?? []).map { object in
                var object = object
                var config = object["config"] as? [String: Any] ?? [:]
                if object["uid"] as? String == kw { config["keyword"] = "rpalette"; config["text"] = "Look up {query}" }
                if object["uid"] as? String == url { config["url"] = "https://example.com/?q={query}" }
                object["config"] = config
                return object
            }
        }
        library.reload()
        guard let launcher = model.launcher else { return }
        await showAgain(launcher)
        lm.query = "rpalette reach"
        try? await Task.sleep(for: .milliseconds(300))
        check("typing the keyword shows its row in the launcher", lm.results.contains { $0.title == "Look up reach" },
              lm.results.map(\.title).joined(separator: ", "))
        lm.openSelected()
        try? await Task.sleep(for: .milliseconds(200))
        check("↩ opens the Open URL it is connected to", opened.last?.absoluteString == "https://example.com/?q=reach",
              opened.map(\.absoluteString).joined(separator: ", "))
    }
}
