import AppKit
import ReachKit

extension Snapshot {
    /// S-063: the palette beside the canvas, its categories collapsed and the
    /// search field empty, in the Workflows window `window` returns.
    static func capturePalette(dir: String, window: () -> NSWindow?) async {
        let palette = WorkflowPaletteState.shared
        palette.filter = ""
        palette.expanded = []
        palette.shown = true
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            try? await Task.sleep(for: .seconds(0.8))
            capture(to: "\(dir)/workflows-palette-\(mode).png", window: window())
        }
        palette.shown = false
    }
}

extension Snapshot {
    /// S-064: the Configure Object… sheets for Keyword, Script Filter, Run Script and Open URL.
    static func captureObjectSheets(dir: String, window: () -> NSWindow?) async {
        let library = WorkflowLibrary.shared
        guard let example = library.selected, let keyword = WorkflowPalette.kind(KeywordInput.type),
              let runScript = WorkflowPalette.kind(Workflow.runScript) else { return }
        // Hello World has a Script Filter and an Open URL; add a Keyword and a Run Script beside them.
        library.add(keyword, at: WorkflowPoint(x: 40, y: 260), in: example, undo: nil, uid: "SNAPKEYWORD")
        library.add(runScript, at: WorkflowPoint(x: 300, y: 300), in: library.selected ?? example, undo: nil, uid: "SNAPSCRIPT")
        try? WorkflowFolder.update(example.folder) { plist in
            WorkflowEdit.configure("SNAPKEYWORD", values: ["keyword": .string("todo"), "text": .string("Add a to-do"),
                                                           "subtext": .string("Type the task")], in: &plist)
            WorkflowEdit.configure("SNAPSCRIPT", values: ["script": .string("echo -n \"$1\" | pbcopy\nosascript -e 'display notification \"Copied\"'")],
                                   in: &plist)
        }
        library.reload()
        for (name, uid) in [("keyword", "SNAPKEYWORD"), ("scriptfilter", "HELLO"), ("runscript", "SNAPSCRIPT"), ("openurl", "WEB")] {
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                library.configureObject(uid)
                try? await Task.sleep(for: .seconds(1))
                capture(to: "\(dir)/workflow-object-\(name)-\(mode).png", window: window()?.attachedSheet)
                library.configuringObject = nil
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
        if let current = library.selected { library.delete(["SNAPKEYWORD", "SNAPSCRIPT"], in: current, undo: nil) }
        library.selectedObjects = []
    }
}
