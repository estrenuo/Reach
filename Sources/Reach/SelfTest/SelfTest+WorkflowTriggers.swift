import Foundation
import ReachKit

extension SelfTest {
    /// S-049: a pressed workflow hotkey runs what is connected with Alfred's
    /// argument, and a combination Reach or another hotkey has stays off.
    /// The press is injected; no real key is registered in a test run.
    static func checkWorkflowHotkeys(model: AppModel) async {
        let lm = model.launcherModel
        let library = lm.workflows.library
        let hotkeys = WorkflowHotkeys.shared
        guard let workflow = library.workflow("selftest.workflow") else { return }
        let realCopier = lm.copier, realSelection = lm.readSelection, realClipboard = lm.readClipboard, realRun = hotkeys.run
        var copied: [String] = []
        var pressed: [String] = []
        lm.copier = { copied.append($0) }
        lm.readSelection = { .text("picked", source: "TextEdit") }
        lm.readClipboard = { "clip" }
        hotkeys.run = { _, hotkey in pressed.append(hotkey.uid) }
        let key = { (uid: String) in WorkflowHotkeys.key(workflow, uid) }
        let other = KeyCombo(keyCode: 40, modifiers: KeyCombo.control | KeyCombo.option)
        defer {
            lm.copier = realCopier
            lm.readSelection = realSelection
            lm.readClipboard = realClipboard
            hotkeys.run = realRun
            for uid in ["HKNONE", "HKSEL", "HKCLIP"] { hotkeys.set(nil, for: workflow, uid: uid) }
        }

        check("a workflow's Hotkey triggers are read", workflow.hotkeys.map(\.uid) == ["HKNONE", "HKSEL", "HKCLIP", "HKFIND"])
        hotkeys.set(.init(combo: HotkeyCenter.shared.combo, keyName: "Space"), for: workflow, uid: "HKNONE")
        hotkeys.set(.init(combo: other, keyName: "K"), for: workflow, uid: "HKSEL")
        hotkeys.set(.init(combo: other, keyName: "K"), for: workflow, uid: "HKCLIP")
        check("a hotkey with a combination is turned on", hotkeys.isRegistered(key("HKSEL")))
        check("a hotkey on Reach's launcher hotkey stays off and says why",
              !hotkeys.isRegistered(key("HKNONE")) && hotkeys.problems[key("HKNONE")] == "Not active: it is Reach's launcher hotkey.",
              hotkeys.problems[key("HKNONE")] ?? "on")
        check("a hotkey another hotkey took first stays off, in the debugger too",
              !hotkeys.isRegistered(key("HKCLIP"))
                  && library.log.shown(.errors).contains { $0.text == "A hotkey was not turned on: another hotkey in this workflow has it." },
              hotkeys.problems[key("HKCLIP")] ?? "on")

        hotkeys.press(key("HKSEL"))
        check("a press runs its workflow's trigger", pressed == ["HKSEL"], pressed.joined(separator: ", "))

        for uid in ["HKNONE", "HKSEL", "HKCLIP", "HKFIND"] {
            if let hotkey = workflow.hotkeys.first(where: { $0.uid == uid }) { await lm.runHotkey(hotkey, in: workflow) }
        }
        check("each hotkey passes Alfred's argument: none, the selection, the clipboard",
              copied.prefix(3) == ["copied ", "copied picked", "copied clip"], copied.joined(separator: " | "))
        check("an argument Reach does not pass runs without it and is logged",
              copied.last == "copied " && library.log.shown(.errors).last?.text
                  == "Reach does not pass the Find pasteboard yet; the hotkey ran without it.",
              library.log.shown(.errors).last?.text ?? "none")

        library.setEnabled(false, workflow)
        check("Turn Off takes the workflow's hotkeys off", !hotkeys.isRegistered(key("HKSEL")))
        if let current = library.workflow(workflow.id) { library.setEnabled(true, current) }
        check("Turn On puts them back", hotkeys.isRegistered(key("HKSEL")))
    }

    /// S-050: a workflow's File Action shows in the action panel for the files
    /// it is for, and runs what is connected with their paths. Copy to
    /// Clipboard is recorded; the files are temporary ones in /tmp.
    static func checkWorkflowFileActions(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let folder = URL(fileURLWithPath: "/tmp/Reach-selftest-fileactions-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let notes = folder.appending(path: "notes.txt"), todo = folder.appending(path: "todo.txt"), photo = folder.appending(path: "photo.png")
        for file in [notes, todo, photo] { FileManager.default.createFile(atPath: file.path, contents: Data("x".utf8)) }
        let realCopier = lm.copier
        var copied: [String] = []
        lm.copier = { copied.append($0) }
        defer {
            lm.copier = realCopier
            try? FileManager.default.removeItem(at: folder)
            launcher.hide()
        }
        func titles() -> [String] { lm.actions?.rows.map(\.title) ?? [] }
        func run(_ title: String) {
            if let index = lm.actions?.rows.firstIndex(where: { $0.title == title }) { lm.runAction(at: index) }
        }

        launcher.show()
        lm.showActions(for: .files([notes]))
        check("a text file's action panel lists the workflow's text action after Reach's own",
              titles().suffix(2) == ["Self Test Text Action", "Self Test Files Universal"]
                  && !titles().contains("Self Test Image Action") && lm.actions?.rows.last?.kindLabel == "Self Test",
              titles().joined(separator: ", "))
        lm.actions?.filter = "self test text"
        check("the filter finds it by name", titles() == ["Self Test Text Action"], titles().joined(separator: ", "))
        run("Self Test Text Action")
        check("choosing it runs what is connected with the file's path, and the launcher hides",
              copied == ["copied \(notes.path)"] && !launcher.isVisible, copied.joined(separator: " | "))

        launcher.show()
        lm.showActions(for: .files([notes, todo]))
        run("Self Test Text Action")
        check("for several files it gets their paths, tab-separated", copied.last == "copied \(notes.path)\t\(todo.path)",
              copied.last ?? "none")

        launcher.show()
        lm.showActions(for: .files([photo]))
        check("an image shows the image action, not the text action",
              titles().contains("Self Test Image Action") && !titles().contains("Self Test Text Action"), titles().joined(separator: ", "))
        lm.showActions(for: .files([photo, notes]))
        check("an action for one file, or for other types, stays out with several files",
              !titles().contains("Self Test Text Action") && !titles().contains("Self Test Image Action"), titles().joined(separator: ", "))

        // S-052: Universal Actions, for selected text and for files.
        launcher.show()
        lm.showActions(for: .text("hello there", source: "TextEdit"))
        check("selected text lists the workflow's text Universal Action, not the one for files",
              titles().contains("Self Test Text Universal") && !titles().contains("Self Test Files Universal"), titles().joined(separator: ", "))
        run("Self Test Text Universal")
        check("choosing it sends the selected text on", copied.last == "copied hello there", copied.last ?? "none")
        launcher.show()
        lm.showActions(for: .text("https://example.com/docs", source: "Safari"))
        check("a selected web address leaves out an action that does not take URLs",
              !titles().contains("Self Test Text Universal"), titles().joined(separator: ", "))
        lm.showActions(for: .files([notes, todo]))
        check("files list the Universal Action that takes files", titles().contains("Self Test Files Universal"),
              titles().joined(separator: ", "))
        run("Self Test Files Universal")
        check("choosing it sends the paths on, tab-separated", copied.last == "copied \(notes.path)\t\(todo.path)", copied.last ?? "none")

        if let workflow = lm.workflows.library.workflow("selftest.workflow") {
            lm.workflows.library.setEnabled(false, workflow)
            lm.showActions(for: .files([notes]))
            check("a workflow that is off adds no action", !titles().contains("Self Test Text Action"), titles().joined(separator: ", "))
            if let current = lm.workflows.library.workflow(workflow.id) { lm.workflows.library.setEnabled(true, current) }
        }
    }
}
