import Foundation
import ReachKit

extension SelfTest {
    /// S-051: ↩ on a keyword runs through Split Arguments and Replace, and a
    /// File Filter lists files. Copy to Clipboard and Spotlight are fakes.
    static func checkWorkflowUtilities(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let realCopier = lm.copier
        var copied: [String] = []
        lm.copier = { copied.append($0) }
        defer {
            lm.copier = realCopier
            launcher.hide()
        }
        func enter(_ query: String) async {
            await showAgain(launcher)
            lm.query = query
            try? await Task.sleep(for: .milliseconds(50))
            lm.openSelected()
            try? await Task.sleep(for: .milliseconds(50))
        }

        await enter("rsplit one, two")
        check("Split Arguments runs what is after it once for each part, trimmed",
              copied == ["copied one", "copied two"], copied.joined(separator: " | "))

        await enter("rrepl https://github.com/estrenuo/Reach/pull/9")
        check("Replace rewrites the text with a regular expression and its groups",
              copied.last == "copied estrenuo/Reach", copied.last ?? "none")

        // S-052
        await enter("rjson hello")
        check("JSON Config sets the next object's configuration, filled with the text it got",
              copied.last == "json hello", copied.last ?? "none")

        await enter("rjoin one, two")
        check("Join Arguments puts the parts of a Split back together with its delimiter",
              copied.last == "copied one+two", copied.last ?? "none")

        await showAgain(launcher)
        lm.query = "zzqxv selftest"
        try? await Task.sleep(for: .milliseconds(400))
        let titles = lm.results.map(\.title)
        let row = titles.firstIndex(of: "Self Test fallback for 'zzqxv selftest'")
        check("a workflow's Fallback Search shows after the web searches when nothing matches",
              row != nil && row == titles.count - 1 && titles.first?.hasPrefix("Search Google") == true, titles.joined(separator: ", "))
        if let row { lm.open(at: row) }
        check("↩ on it sends the typed text on", copied.last == "copied zzqxv selftest", copied.last ?? "none")

        // S-053: the terminal is recorded, never opened.
        let realTerminal = lm.openTerminal
        var terminals: [String] = []
        lm.openTerminal = { terminals.append($0.path); return true }
        await enter("rterm /tmp")
        lm.openTerminal = realTerminal
        check("Browse in Terminal opens the terminal at the path", terminals == ["/tmp"], terminals.joined(separator: ", "))

        // Keys are recorded, never pressed.
        let realKeys = lm.pressKeys
        var pressed: [WorkflowKeys] = []
        lm.pressKeys = { pressed.append($0); return true }
        await enter("rkeys hello")
        lm.pressKeys = realKeys
        check("Dispatch Key Combo presses ⌘V once and the workflow goes on",
              pressed == [WorkflowKeys(keyCode: 9, modifiers: 1 << 20)] && copied.last == "copied hello", "\(pressed) \(copied.last ?? "")")

        let realRun = lm.workflows.run
        var gridAsked: [String] = []
        lm.workflows.run = { command in
            gridAsked.append(URL(fileURLWithPath: command.executable).lastPathComponent)
            gridAsked.append(command.arguments.joined(separator: " "))
            return ScriptResult(output: Data(#"{"items": [{"title": "Grid one", "arg": "one"}, {"title": "Grid two", "arg": "two"}]}"#.utf8))
        }
        await enter("rgrid Red")
        try? await Task.sleep(for: .milliseconds(100))
        check("a Grid View runs its script file with the text and shows its items in the launcher",
              gridAsked == ["grid.sh", "Red"] && launcher.isVisible && lm.results.prefix(2).map(\.title) == ["Grid one", "Grid two"],
              "\(gridAsked) \(lm.results.map(\.title))")
        lm.query = "two"
        try? await Task.sleep(for: .milliseconds(50))
        check("typing filters the grid's items", lm.results.first?.title == "Grid two", lm.results.map(\.title).joined(separator: ", "))
        lm.openSelected()
        try? await Task.sleep(for: .milliseconds(50))
        check("↩ on an item sends its argument on along the grid's lines", copied.last == "copied two", copied.last ?? "none")
        // S-054: ⇧↩ follows the ⇧ line.
        let realLarge = lm.largeType
        var large: [String] = []
        lm.largeType = { large.append($0) }
        await enter("rgrid Red")
        try? await Task.sleep(for: .milliseconds(100))
        let shifted = lm.runAlternative(.shift)
        lm.largeType = realLarge
        lm.workflows.run = realRun
        check("⇧↩ on a workflow row follows its ⇧ line", shifted && large == ["one"], "\(shifted) \(large)")

        // S-054: a fake browser answers.
        let realTab = lm.readCurrentTab
        lm.readCurrentTab = { .success("https://github.com/estrenuo/Reach") }
        await enter("rtab")
        try? await Task.sleep(for: .milliseconds(100))
        check("the Current Tab task sends the front browser tab's URL on", copied.last == "copied https://github.com/estrenuo/Reach",
              copied.last ?? "none")
        lm.readCurrentTab = { .failure(WorkflowProblem(kind: "Allow Reach to control Safari in System Settings > Privacy & Security > Automation.")) }
        await enter("rtab")
        try? await Task.sleep(for: .milliseconds(100))
        lm.readCurrentTab = realTab
        check("without permission the debugger says where to allow it, and allow_empty goes on with no text",
              copied.last == "copied " && lm.workflows.library.log.shown(.errors).last?.text.hasPrefix("Allow Reach to control Safari") == true,
              copied.last ?? "none")

        // Action in Alfred: a path gets the file's panel, other text the text panel.
        let renamed = URL(fileURLWithPath: "/tmp/Reach-selftest-renamed-\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: renamed.path, contents: Data("x".utf8))
        defer { try? FileManager.default.removeItem(at: renamed) }
        await enter("ract \(renamed.path)")
        check("Action in Alfred opens the action panel for the file, and the launcher stays",
              launcher.isVisible && lm.actions?.url == renamed, lm.actions?.target.title ?? "no panel")
        lm.closeActions()
        await enter("ract hello")
        check("for text that is not a path it opens the panel for the text",
              launcher.isVisible && lm.actions?.text == "hello", lm.actions?.target.title ?? "no panel")
        lm.closeActions()

        // S-055
        await enter("rwait later")
        let early = copied.last
        try? await Task.sleep(for: .milliseconds(400))
        check("Delay waits, then sends the text on", early != "copied later" && copied.last == "copied later", copied.last ?? "none")

        // Dialogs are recorded, never shown.
        let realDialog = lm.showDialog
        var dialogs: [String] = []
        lm.showDialog = { title, text, buttons in dialogs.append("\(title) / \(text) / \(buttons.joined(separator: ","))") }
        await enter("rask Safari")
        lm.showDialog = realDialog
        check("Dialog shows its filled title, text and buttons", dialogs == ["About Safari / Details / Ok"], dialogs.joined())

        // Terminal commands are recorded, never run.
        let realShell = lm.runShell
        var shells: [String] = []
        lm.runShell = { shells.append($0.command); return true }
        await enter("rbrew wget")
        lm.runShell = realShell
        check("Terminal Command runs the filled command in the terminal", shells == ["brew install wget"], shells.joined())

        // A Text View is recorded, not shown.
        let realText = lm.showText
        var texts: [String] = []
        lm.showText = { texts.append("\($0): \($1)") }
        await enter("rinfo wget 1.25")
        lm.showText = realText
        check("Text View shows the text under the workflow's name", texts.count == 1 && texts[0].hasSuffix(": wget 1.25"), texts.joined())

        // Shortcuts never runs: a fake answers for /usr/bin/shortcuts.
        let realShortcuts = lm.workflows.run
        var shortcuts: [[String]] = []
        lm.workflows.run = { command in
            shortcuts.append(command.arguments)
            return ScriptResult(output: Data("echoed\n".utf8))
        }
        await enter("rshort hello")
        try? await Task.sleep(for: .milliseconds(100))
        check("Run Shortcut runs the shortcut JSON Config names with the text, and goes on with what it prints",
              shortcuts.first?.suffix(2) == ["Echo", "hello"] && copied.last == "copied echoed", "\(shortcuts) \(copied.last ?? "")")
        await enter("rview Echo")
        try? await Task.sleep(for: .milliseconds(100))
        lm.workflows.run = realShortcuts
        check("View Shortcut opens the shortcut in Shortcuts", shortcuts.last == ["view", "Echo"], "\(shortcuts)")

        // Finder is never asked: a fake answers for osascript.
        let realFinder = lm.workflows.run
        lm.workflows.run = { command in
            let script = command.arguments.last ?? ""
            return ScriptResult(output: Data((script.contains("selection") ? "/tmp/a.txt\t/tmp/b.txt" : "/tmp/folder/").utf8))
        }
        await enter("rsel")
        try? await Task.sleep(for: .milliseconds(100))
        check("Finder Selection sends the selected files on, tab-separated", copied.last == "copied /tmp/a.txt\t/tmp/b.txt", copied.last ?? "")
        await enter("rwin")
        try? await Task.sleep(for: .milliseconds(100))
        lm.workflows.run = realFinder
        check("Current Finder Window sends its folder on", copied.last == "copied /tmp/folder/", copied.last ?? "")

        // A File Filter: Spotlight skips /tmp, so a fake answers with temp files.
        let folder = URL(fileURLWithPath: "/tmp/Reach-selftest-filefilter-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let report = folder.appending(path: "report.txt")
        FileManager.default.createFile(atPath: report.path, contents: Data("x".utf8))
        let realFind = lm.workflows.findFiles
        defer { lm.workflows.findFiles = realFind }
        var asked: [String] = []
        lm.workflows.findFiles = { predicate, _, _, done in
            asked.append(predicate)
            done([LaunchResult(id: report.path, title: "report.txt", subtitle: report.path, icon: .file(report.path), url: report)])
        }
        await showAgain(launcher)
        lm.query = "rfil"
        check("part of a File Filter's keyword offers it", lm.results.contains { $0.completes == "rfiles " },
              lm.results.map(\.title).joined(separator: ", "))
        lm.query = "rfiles rep"
        try? await Task.sleep(for: .milliseconds(100))
        check("a File Filter asks Spotlight for the text in the names, of its types only",
              asked.last?.contains(#"kMDItemDisplayName == "rep*"cdw"#) == true
                  && asked.last?.contains(#"kMDItemContentTypeTree == "public.plain-text""#) == true, asked.last ?? "not asked")
        check("its files show first, named by the file", lm.results.first?.title == "report.txt",
              lm.results.map(\.title).joined(separator: ", "))
        lm.openSelected()
        try? await Task.sleep(for: .milliseconds(50))
        check("↩ on a file sends its path on", copied.last == "copied \(report.path)", copied.last ?? "none")
    }
}
