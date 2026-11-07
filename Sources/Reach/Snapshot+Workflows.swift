import AppKit
import ReachKit

extension Snapshot {
    /// The launcher with a sample workflow's File Action, File Filter, Fallback
    /// Search, Universal Action, and Grid View (S-050 to S-053).
    static func workflowShots(model: AppModel) -> [LauncherShot] {
        let lm = model.launcherModel
        let (realRun, realFind) = (lm.workflows.run, lm.workflows.findFiles)
        let samples = ((try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: SampleFiles.folder),
                                                                     includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.path < $1.path }
        return [
            // S-050: a sample workflow's File Action after Reach's own, filtered by "op".
            LauncherShot(name: "file-actions", workflow: ("snapshot-fileaction", ["name": "Image Tools", "objects": [
                ["uid": "FA", "type": WorkflowFileAction.type, "config": ["name": "Optimize Images", "acceptsmulti": 1]],
            ]]), prepare: { model in
                if let sample = samples.first(where: { !$0.hasDirectoryPath }) { model.launcherModel.showActions(for: .files([sample])) }
                model.launcherModel.actions?.filter = "op"
                try? await Task.sleep(for: .seconds(0.5))
            }),
            // S-051: a sample workflow's File Filter, with the sample files for Spotlight's answer.
            LauncherShot(name: "file-filter", workflow: ("snapshot-filefilter", ["name": "Visual Studio Code", "objects": [
                ["uid": "FF", "type": FileFilter.type, "config": [
                    "keyword": "codef", "withspace": true, "title": "Find and open with Visual Studio Code",
                    "subtext": "Open files and folders",
                ]],
            ]]), prepare: { model in
                let lm = model.launcherModel
                lm.workflows.findFiles = { _, _, _, done in
                    done(samples.prefix(4).map { url in
                        LaunchResult(id: url.path, title: url.lastPathComponent,
                                     subtitle: (url.path as NSString).abbreviatingWithTildeInPath, icon: .file(url.path), url: url)
                    })
                }
                lm.query = "codef brief"
                try? await Task.sleep(for: .seconds(0.8))
            }, cleanUp: { $0.launcherModel.workflows.findFiles = realFind }),
            // S-052: a sample workflow's Fallback Search below the web searches.
            LauncherShot(name: "workflow-fallback", query: "zzqxv meeting notes", workflow: ("snapshot-fallback", ["name": "Shimmering Obsidian", "objects": [
                ["uid": "FB", "type": WorkflowFallback.type, "config": ["text": "Search Vault: '{query}'"]],
            ]])),
            // S-052: a sample workflow's Universal Action on selected text, filtered by "a".
            LauncherShot(name: "selection-universal", workflow: ("snapshot-universal", ["name": "ChatGPT", "objects": [
                ["uid": "UA", "type": WorkflowUniversalAction.type, "config": ["name": "Ask ChatGPT", "acceptstext": true]],
            ]]), prepare: { model in
                model.launcherModel.showActions(for: .text("The quick brown fox jumps over the lazy dog.", source: "TextEdit"))
                model.launcherModel.actions?.filter = "a"
                try? await Task.sleep(for: .seconds(0.8))
            }),
            // S-053: a sample Grid View's items, from a fake script, filtered by "q".
            LauncherShot(name: "workflow-grid", workflow: ("snapshot-grid", ["name": "Tag Finder", "objects": [
                ["uid": "GRID", "type": Workflow.grid, "config": ["inputtype": 1, "inputfile": "getTaggedFiles.sh", "filterable": true]],
            ]]), prepare: { model in
                let lm = model.launcherModel
                let items = samples.prefix(5).map { url in
                    ["title": url.lastPathComponent, "subtitle": (url.path as NSString).abbreviatingWithTildeInPath, "arg": url.path,
                     "icon": ["type": "fileicon", "path": url.path]] as [String: Any]
                }
                let json = (try? JSONSerialization.data(withJSONObject: ["items": items])) ?? Data()
                lm.workflows.run = { _ in ScriptResult(output: json) }
                if let workflow = WorkflowLibrary.shared.workflow("snapshot-grid.workflow") {
                    let folder = WorkflowLibrary.shared.folder.appending(path: "snapshot-grid.workflow", directoryHint: .isDirectory)
                    let command = ScriptCommand(executable: folder.appending(path: "getTaggedFiles.sh").path,
                                                arguments: ["Red"], directory: folder)
                    lm.workflows.showGrid(WorkflowGridRun(uid: "GRID", command: command), in: workflow)
                }
                lm.query = ""
                lm.refresh()
                try? await Task.sleep(for: .seconds(0.8))
            }, cleanUp: { model in
                model.launcherModel.workflows.run = realRun
                model.launcherModel.workflows.forget()
            }),
        ]
    }

    /// S-042: the Workflows window with nothing selected and with sample workflows.
    static func captureWorkflows(model: AppModel, dir: String) async {
        let library = WorkflowLibrary.shared
        // The launcher view hands over openWindow when it first shows.
        model.launcher?.show()
        try? await Task.sleep(for: .seconds(0.5))
        model.launcher?.hide()
        let saved = library.workflows.map(\.folder)
        // Only sample workflows in the shots, in the /tmp library.
        let parked = FileManager.default.temporaryDirectory.appending(path: "Reach-parked-workflows-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: parked, withIntermediateDirectories: true)
        for folder in saved { try? FileManager.default.moveItem(at: folder, to: parked.appending(path: folder.lastPathComponent)) }
        library.reload()
        defer {
            for folder in library.workflows.map(\.folder) { try? FileManager.default.removeItem(at: folder) }
            for folder in saved { try? FileManager.default.moveItem(at: parked.appending(path: folder.lastPathComponent), to: folder) }
            try? FileManager.default.removeItem(at: parked)
            library.selection = nil
            library.reload()
        }
        model.launcherModel.openWorkflows()
        try? await Task.sleep(for: .seconds(1))
        let window = { NSApp.windows.first { $0.isVisible && $0.identifier?.rawValue.hasPrefix(WorkflowLibrary.windowID) == true } }
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            library.selection = nil
            try? await Task.sleep(for: .seconds(0.8))
            capture(to: "\(dir)/workflows-empty-\(mode).png", window: window())
        }
        library.addExample()
        if let folder = try? WorkflowFolder.addExample(into: library.folder) {
            try? WorkflowFolder.update(folder) {
                $0["name"] = "GitHub Repos"
                $0["createdby"] = "Ada Lovelace"
                $0["version"] = "2.1"
                $0["description"] = "Search your repositories."
                $0["disabled"] = true
            }
        }
        library.reload()
        library.selection = library.workflows.first { $0.name == "Hello World" }?.id
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            try? await Task.sleep(for: .seconds(0.8))
            capture(to: "\(dir)/workflows-\(mode).png", window: window())
        }
        // S-061: a selected card, which the arrow keys move.
        library.selectedObjects = ["COPY"]
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            try? await Task.sleep(for: .seconds(0.8))
            capture(to: "\(dir)/workflows-selected-\(mode).png", window: window())
        }
        library.selectedObjects = []
        await captureWorkflowsMultiSelect(dir: dir, window: window)
        await capturePalette(dir: dir, window: window)
        await captureObjectSheets(dir: dir, window: window)
        await captureConnections(dir: dir, window: window)
        // Configure Workflow… (S-043): as installed, then with the required field emptied.
        for (name, greeting) in [("workflow-configure", nil), ("workflow-configure-missing", "")] as [(String, String?)] {
            guard let example = library.selected else { break }
            if let greeting { library.saveConfiguration(["greeting": greeting], for: example) }
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                library.configuring = library.selected
                try? await Task.sleep(for: .seconds(0.8))
                capture(to: "\(dir)/\(name)-\(mode).png", window: window()?.attachedSheet)
                library.configuring = nil
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
        // Workflow Info… (S-046): each tab, and Variables before and after one is added.
        let tabs: [(String, WorkflowInfoSheet.Tab)] = [("about", .about), ("readme", .readme), ("variables-empty", .variables)]
        for (name, tab) in tabs + [("variables", .variables)] {
            if name == "variables", let example = library.selected {
                var info = WorkflowInfo(example)
                info.variables = [WorkflowVariable(name: "api_key", value: "sk-12345", dontExport: true),
                                  WorkflowVariable(name: "user", value: "ada")]
                library.saveInfo(info, for: example)
            }
            library.infoTab = tab
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                library.editingInfo = library.selected
                try? await Task.sleep(for: .seconds(0.8))
                capture(to: "\(dir)/workflow-info-\(name)-\(mode).png", window: window()?.attachedSheet)
                library.editingInfo = nil
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
        library.infoTab = .about
        // Hotkeys… (S-049): one set, one empty, one on Reach's launcher hotkey.
        if let example = library.selected {
            try? WorkflowFolder.update(example.folder) {
                $0["objects"] = ($0["objects"] as? [[String: Any]] ?? []) + [
                    ["uid": "HKSET", "type": WorkflowHotkey.type, "config": ["argument": 1]],
                    ["uid": "HKEMPTY", "type": WorkflowHotkey.type, "config": ["argument": 2]],
                    ["uid": "HKTAKEN", "type": WorkflowHotkey.type, "config": ["argument": 0]],
                ]
            }
            library.reload()
            let hotkeys = WorkflowHotkeys.shared
            if let current = library.selected {
                hotkeys.set(.init(combo: KeyCombo(keyCode: 40, modifiers: KeyCombo.control | KeyCombo.option), keyName: "K"),
                            for: current, uid: "HKSET")
                hotkeys.set(.init(combo: HotkeyCenter.shared.combo, keyName: "Space"), for: current, uid: "HKTAKEN")
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    library.editingHotkeys = current
                    try? await Task.sleep(for: .seconds(0.8))
                    capture(to: "\(dir)/workflow-hotkeys-\(mode).png", window: window()?.attachedSheet)
                    library.editingHotkeys = nil
                    try? await Task.sleep(for: .seconds(0.5))
                }
                hotkeys.set(nil, for: current, uid: "HKSET")
                hotkeys.set(nil, for: current, uid: "HKTAKEN")
            }
        }
        // The debugger (S-045) with a run that printed and one that failed.
        if let example = library.selected {
            library.log.clear()
            library.record(example, object: "Script Filter", input: "hello Ada",
                           result: ScriptResult(output: Data(#"{"items":[{"title":"Hello, Ada","arg":"Hello, Ada"}]}"#.utf8)))
            library.record(example, object: "Run Script", input: nil,
                           result: ScriptResult(errors: "say: command not found", status: 127))
            library.debugging = true
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                try? await Task.sleep(for: .seconds(0.8))
                capture(to: "\(dir)/workflows-debugger-\(mode).png", window: window())
            }
            library.debugging = false
            library.log.clear()
        }
        window()?.close()
        // S-055: a workflow's Text View, as Homebrew shows `brew info`.
        TextViewWindow.shared.show(title: "Homebrew", text: """
            ==> wget: stable 1.25.0 (bottled), HEAD
            Internet file retriever
            https://www.gnu.org/software/wget/
            Not installed
            From: https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/w/wget.rb
            License: GPL-3.0-or-later
            ==> Dependencies
            Build: pkgconf ✘
            Required: libidn2 ✘, openssl@3 ✔
            """)
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            try? await Task.sleep(for: .seconds(0.8))
            capture(to: "\(dir)/workflows-textview-\(mode).png", window: TextViewWindow.shared.shown)
        }
        TextViewWindow.shared.hide()
    }
}
