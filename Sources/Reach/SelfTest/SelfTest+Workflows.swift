import Foundation
import ReachKit

extension SelfTest {
    /// S-041: a workflow's keyword runs its script filter. While the script
    /// runs the placeholder shows with "please wait"; then its rows replace it.
    /// A fake runner answers when the check says so, so no script ever runs.
    static func checkWorkflows(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let library = lm.workflows.library
        let folder = library.folder.appending(path: "selftest.workflow", directoryHint: .isDirectory)
        let plist: [String: Any] = [
            "bundleid": "com.reach.selftest", "name": "Self Test", "createdby": "Reach",
            "objects": [
                ["uid": "SF", "type": ScriptFilter.type, "config": [
                    "keyword": "rtest", "withspace": true, "argumenttype": 0, "title": "Search Self Test",
                    "runningsubtext": "Looking…", "script": "echo", "type": 0, "scriptargtype": 1,
                ]],
                ["uid": "URL", "type": Workflow.openURL, "config": ["url": "https://example.com/{query}"]],
                ["uid": "COPY", "type": Workflow.copyToClipboard, "config": ["clipboardtext": "copied {query}"]],
                // S-047: a Keyword input whose keyword comes from a variable.
                ["uid": "KW", "type": KeywordInput.type, "config": [
                    "keyword": "{var:kw}", "withspace": true, "argumenttype": 0, "text": "Open {query}",
                ]],
                // S-047: keywords whose Return reaches an Automation Task, or an
                // External Trigger that shows the rkey keyword again.
                ["uid": "TASKKW", "type": KeywordInput.type, "config": ["keyword": "rtask", "argumenttype": 2, "text": "Task"]],
                ["uid": "TASK", "type": "alfred.workflow.automation.task", "config": [:]],
                ["uid": "BACKKW", "type": KeywordInput.type, "config": ["keyword": "rback", "argumenttype": 0, "text": "Back"]],
                ["uid": "IF", "type": Workflow.conditional, "config": ["conditions": [
                    ["uid": "ISWORLD", "inputstring": "", "matchmode": 0, "matchstring": "world"],
                ]]],
                ["uid": "CALL", "type": Workflow.callExternalTrigger, "config": [
                    "externaltriggerid": "again", "workflowbundleid": "self", "passinputasargument": true,
                ]],
                ["uid": "AGAIN", "type": Workflow.externalTrigger, "config": ["triggerid": "again"]],
                // S-048: Post Notification passes the text on to Copy to Clipboard.
                ["uid": "NOTEKW", "type": KeywordInput.type, "config": ["keyword": "rnote", "argumenttype": 0, "text": "Note"]],
                ["uid": "NOTE", "type": Workflow.notification, "config": ["title": "Done", "text": "{query}"]],
                ["uid": "SOUND", "type": Workflow.playSound, "config": ["soundname": "Blow", "systemsound": true]],
                ["uid": "DEBUG", "type": Workflow.debug, "config": ["argument": "debug {query}", "processoutputs": true]],
                ["uid": "TRASHKW", "type": KeywordInput.type, "config": ["keyword": "rtrash", "argumenttype": 0, "text": "Trash"]],
                ["uid": "TRASH", "type": Workflow.automationTask, "config": [
                    "taskuid": Workflow.trashTask, "tasksettings": ["target_path": "/tmp/{query}"],
                ]],
                // S-049: Hotkey triggers with each kind of argument.
                ["uid": "HKNONE", "type": WorkflowHotkey.type, "config": ["action": 0, "argument": 0]],
                ["uid": "HKSEL", "type": WorkflowHotkey.type, "config": ["action": 0, "argument": 1]],
                ["uid": "HKCLIP", "type": WorkflowHotkey.type, "config": ["action": 0, "argument": 2]],
                ["uid": "HKFIND", "type": WorkflowHotkey.type, "config": ["action": 0, "argument": 4]],
                // S-051: Split Arguments, as arguments, on a comma.
                ["uid": "SPLITKW", "type": KeywordInput.type, "config": ["keyword": "rsplit", "argumenttype": 0, "text": "Split"]],
                ["uid": "SPLIT", "type": Workflow.split, "config": ["delimiter": ",", "outputas": 1, "trimarguments": true]],
                // S-051: Replace with a regular expression and its groups.
                ["uid": "REPLKW", "type": KeywordInput.type, "config": ["keyword": "rrepl", "argumenttype": 0, "text": "Replace"]],
                ["uid": "REPL", "type": Workflow.replace, "config": [
                    "matchmode": 1, "matchstring": #".*github.com\/([^\/?]*\/[^\/?]*).*"#, "replacestring": "$1",
                ]],
                // S-052: JSON Config sets the argument and Copy to Clipboard's text.
                ["uid": "JSONKW", "type": KeywordInput.type, "config": ["keyword": "rjson", "argumenttype": 0, "text": "JSON"]],
                ["uid": "JSON", "type": Workflow.json, "config": [
                    "json": #"{"alfredworkflow": {"arg": "{query}!", "config": {"clipboardtext": "json {query}"}}}"#,
                ]],
                // S-052: Split on a comma, then Join Arguments with a plus.
                ["uid": "JOINKW", "type": KeywordInput.type, "config": ["keyword": "rjoin", "argumenttype": 0, "text": "Join"]],
                ["uid": "JOINSPLIT", "type": Workflow.split, "config": ["delimiter": ",", "outputas": 1, "trimarguments": true]],
                ["uid": "JOIN", "type": Workflow.joinArgs, "config": ["delimiter": "+"]],
                // S-053: Browse in Terminal with the argument as the path.
                ["uid": "TERMKW", "type": KeywordInput.type, "config": ["keyword": "rterm", "argumenttype": 0, "text": "Terminal"]],
                ["uid": "TERM", "type": Workflow.browseInTerminal, "config": ["path": ""]],
                // S-053: Dispatch Key Combo presses ⌘V, then Copy to Clipboard.
                ["uid": "KEYSKW", "type": KeywordInput.type, "config": ["keyword": "rkeys", "argumenttype": 0, "text": "Keys"]],
                ["uid": "KEYS", "type": Workflow.dispatchKeys, "config": [
                    "keychar": "v", "keycode": -1, "keymod": 1_048_576, "count": 1, "overridewithargument": false,
                ]],
                // S-053: a Grid View fed by a script file; a fake runner answers.
                ["uid": "GRIDKW", "type": KeywordInput.type, "config": ["keyword": "rgrid", "argumenttype": 0, "text": "Grid"]],
                ["uid": "GRID", "type": Workflow.grid, "config": ["inputtype": 1, "inputfile": "grid.sh", "filterable": true]],
                // S-052: Universal Actions for text (not URLs) and for files.
                ["uid": "UATEXT", "type": WorkflowUniversalAction.type, "config": [
                    "name": "Self Test Text Universal", "acceptstext": true, "acceptsurls": false, "acceptsfiles": false,
                ]],
                ["uid": "UAFILES", "type": WorkflowUniversalAction.type, "config": [
                    "name": "Self Test Files Universal", "acceptsfiles": true, "acceptsmulti": 1,
                ]],
                // S-052: a Fallback Search.
                ["uid": "FALLBACK", "type": WorkflowFallback.type, "config": ["text": "Self Test fallback for '{query}'"]],
                // S-051: a File Filter for text files.
                ["uid": "FF", "type": FileFilter.type, "config": [
                    "keyword": "rfiles", "withspace": true, "argumenttype": 0, "title": "Find Self Test Files",
                    "types": ["public.plain-text"], "anchorfields": true, "limit": 0, "scopes": [String](),
                ]],
                // S-050: File Actions for text files (several) and for one image.
                ["uid": "FATEXT", "type": WorkflowFileAction.type, "config": [
                    "name": "Self Test Text Action", "acceptsmulti": 1, "filetypes": ["public.plain-text"],
                ]],
                ["uid": "FAPNG", "type": WorkflowFileAction.type, "config": [
                    "name": "Self Test Image Action", "acceptsmulti": 0, "filetypes": ["public.png"],
                ]],
            ],
            "variables": ["kw": "rkey"],
            "connections": [
                "SF": [
                    ["destinationuid": "URL", "modifiers": 0],
                    ["destinationuid": "COPY", "modifiers": WorkflowConnection.command, "modifiersubtext": "Copy"],
                ],
                "KW": [["destinationuid": "URL", "modifiers": 0]],
                "TASKKW": [["destinationuid": "TASK", "modifiers": 0]],
                "BACKKW": [["destinationuid": "IF", "modifiers": 0]],
                "IF": [["destinationuid": "CALL", "modifiers": 0, "sourceoutputuid": "ISWORLD"]],
                "AGAIN": [["destinationuid": "KW", "modifiers": 0]],
                "TRASHKW": [["destinationuid": "TRASH", "modifiers": 0]],
                "NOTEKW": [["destinationuid": "NOTE", "modifiers": 0]],
                "NOTE": [["destinationuid": "SOUND", "modifiers": 0]],
                "SOUND": [["destinationuid": "DEBUG", "modifiers": 0]],
                "DEBUG": [["destinationuid": "COPY", "modifiers": 0]],
                "HKNONE": [["destinationuid": "COPY", "modifiers": 0]],
                "HKSEL": [["destinationuid": "COPY", "modifiers": 0]],
                "HKCLIP": [["destinationuid": "COPY", "modifiers": 0]],
                "HKFIND": [["destinationuid": "COPY", "modifiers": 0]],
                "FATEXT": [["destinationuid": "COPY", "modifiers": 0]],
                "SPLITKW": [["destinationuid": "SPLIT", "modifiers": 0]],
                "SPLIT": [["destinationuid": "COPY", "modifiers": 0]],
                "REPLKW": [["destinationuid": "REPL", "modifiers": 0]],
                "REPL": [["destinationuid": "COPY", "modifiers": 0]],
                "FF": [["destinationuid": "COPY", "modifiers": 0]],
                "JSONKW": [["destinationuid": "JSON", "modifiers": 0]],
                "JSON": [["destinationuid": "COPY", "modifiers": 0]],
                "JOINKW": [["destinationuid": "JOINSPLIT", "modifiers": 0]],
                "JOINSPLIT": [["destinationuid": "JOIN", "modifiers": 0]],
                "JOIN": [["destinationuid": "COPY", "modifiers": 0]],
                "FALLBACK": [["destinationuid": "COPY", "modifiers": 0]],
                "UATEXT": [["destinationuid": "COPY", "modifiers": 0]],
                "TERMKW": [["destinationuid": "TERM", "modifiers": 0]],
                "KEYSKW": [["destinationuid": "KEYS", "modifiers": 0]],
                "GRIDKW": [["destinationuid": "GRID", "modifiers": 0]],
                "GRID": [["destinationuid": "COPY", "modifiers": 0]],
                "KEYS": [["destinationuid": "COPY", "modifiers": 0]],
                "UAFILES": [["destinationuid": "COPY", "modifiers": 0]],
                "FAPNG": [["destinationuid": "COPY", "modifiers": 0]],
            ],
        ]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? data.write(to: folder.appending(path: "info.plist"))
        }
        library.reload()

        // The fake scripts wait until `release` answers them.
        let waiting = Shared<[CheckedContinuation<ScriptResult, Never>]>([])
        let ranWith = Shared<[String]>([])
        let output = ScriptResult(output: Data("""
        {"items": [{"title": "Hello one", "arg": "one"}, {"title": "Hello two", "arg": "two"}]}
        """.utf8))
        func release() {
            waiting.value.forEach { $0.resume(returning: output) }
            waiting.value = []
        }
        let run = lm.workflows.run
        let opener = lm.opener
        let copier = lm.copier
        var opened: [URL] = []
        var copied: [String] = []
        lm.workflows.run = { command in
            ranWith.value = command.arguments
            return await withCheckedContinuation { waiting.value.append($0) }
        }
        lm.opener = { opened.append($0); return true }
        lm.copier = { copied.append($0) }
        defer {
            release()
            lm.workflows.run = run
            lm.opener = opener
            lm.copier = copier
            try? FileManager.default.removeItem(at: folder)
            library.reload()
        }

        check("a workflow in the Workflows folder is read", library.workflow("selftest.workflow")?.name == "Self Test")

        launcher.show()
        lm.query = "rtes"
        check("part of the keyword offers the workflow", lm.results.first?.title == "Search Self Test"
              && lm.results.first?.completes == "rtest ", lm.results.map(\.title).joined(separator: ", "))

        lm.query = "rtest hello"
        try? await Task.sleep(for: .milliseconds(50))
        let row = lm.results.first
        check("while the script runs, the placeholder shows with “please wait”",
              row?.title == "Search Self Test" && row?.subtitle == "Looking…" && row?.isOpenable == false,
              "\(row?.title ?? "none") / \(row?.subtitle ?? "")")
        check("the text after the keyword reaches the script", ranWith.value.last == "hello", ranWith.value.joined(separator: " "))

        release()
        try? await Task.sleep(for: .milliseconds(100))
        check("the script's rows replace the placeholder",
              lm.results.prefix(2).map(\.title) == ["Hello one", "Hello two"], lm.results.map(\.title).joined(separator: ", "))
        check("a workflow row names its workflow", lm.results.first?.kindLabel == "Self Test")
        check("the debugger logs the run with the text it got",
              library.log.entries.contains { $0.workflow == "Self Test" && $0.text == "Script Filter ran with “hello”" },
              library.log.entries.map(\.text).joined(separator: " | "))

        lm.openSelected()
        check("↩ runs what is connected: it opens the URL with the row's argument",
              opened == [URL(string: "https://example.com/one")!] && !launcher.isVisible, opened.map(\.absoluteString).joined())

        await showAgain(launcher)
        lm.query = "rtest again"
        try? await Task.sleep(for: .milliseconds(50))
        release()
        try? await Task.sleep(for: .milliseconds(100))
        let handled = lm.runAlternative(.command)
        check("⌘↩ follows the ⌘ line: it copies", handled && copied == ["copied one"], copied.joined(separator: ", "))

        await showAgain(launcher)
        lm.query = "rtest stop"
        try? await Task.sleep(for: .milliseconds(50))
        lm.query = "rtest stopped"
        try? await Task.sleep(for: .milliseconds(50))
        check("a new query runs the script again with the new text", ranWith.value.last == "stopped")
        release()
        try? await Task.sleep(for: .milliseconds(100))

        // S-047: a Keyword input answers its keyword and sends the text on.
        await showAgain(launcher)
        lm.query = "rke"
        check("part of a Keyword input's keyword offers it", lm.results.contains { $0.completes == "rkey " },
              lm.results.map(\.title).joined(separator: ", "))
        lm.query = "rkey world"
        try? await Task.sleep(for: .milliseconds(50))
        check("a Keyword input with its text shows one row, its title filled in", lm.results.first?.title == "Open world",
              lm.results.map(\.title).joined(separator: ", "))
        lm.openSelected()
        check("↩ on a Keyword input runs what is connected: it opens the URL with the text",
              opened.last == URL(string: "https://example.com/world")! && !launcher.isVisible,
              opened.map(\.absoluteString).joined(separator: ", "))

        // S-047: Return follows a Conditional to an External Trigger, and says
        // which object it does not run.
        await showAgain(launcher)
        lm.query = "rback world"
        try? await Task.sleep(for: .milliseconds(50))
        lm.openSelected()
        try? await Task.sleep(for: .milliseconds(50))
        check("↩ through a Conditional and an External Trigger shows the keyword again with the text",
              lm.query == "rkey world" && launcher.isVisible && lm.results.first?.title == "Open world",
              "\(lm.query) \(launcher.isVisible)")
        lm.query = "rtask"
        try? await Task.sleep(for: .milliseconds(50))
        lm.openSelected()
        check("↩ that reaches an Automation Task says Reach does not run it, and the launcher stays",
              lm.errors.values.contains("Reach does not run automation.task yet.") && launcher.isVisible
                  && library.log.shown(.errors).last?.text == "Reach does not run automation.task yet.",
              lm.errors.values.joined(separator: ", "))
        let realPerform = lm.perform
        var trashed: [URL] = []
        lm.perform = { item, urls in
            if case .action(.trash) = item { trashed += urls }
            return true
        }
        lm.query = "rtrash reach-selftest.dmg"
        try? await Task.sleep(for: .milliseconds(50))
        lm.openSelected()
        check("↩ that reaches the Trash task moves the filled-in path to the Trash",
              trashed == [URL(fileURLWithPath: "/tmp/reach-selftest.dmg")], trashed.map(\.path).joined(separator: ", "))
        lm.perform = realPerform

        // S-048: the notification is recorded, never posted.
        let realNotify = lm.notify
        var notes: [String] = []
        lm.notify = { _, title, text in notes.append(title + ": " + text) }
        let realCopier = lm.copier
        var copiedNote: [String] = []
        lm.copier = { copiedNote.append($0) }
        let realSound = lm.playSound
        var sounds: [String] = []
        lm.playSound = { sounds.append($0) }
        await showAgain(launcher)
        lm.query = "rnote hello"
        try? await Task.sleep(for: .milliseconds(50))
        lm.openSelected()
        check("↩ through Post Notification, Play Sound and Debug shows the text, plays the sound, logs it and passes it on",
              notes == ["Done: hello"] && sounds == ["Blow"] && copiedNote == ["copied hello"]
                  && library.log.entries.last { $0.workflow == "Self Test" }?.text == "debug hello",
              "\(notes) \(sounds) \(copiedNote)")
        lm.playSound = realSound
        lm.notify = realNotify
        lm.copier = realCopier
        launcher.hide()
        await checkWorkflowHotkeys(model: model)
        await checkWorkflowFileActions(model: model)
        await checkWorkflowUtilities(model: model)

        // The real runner: a bash script gets the text as $1 and its output parses.
        let script = ScriptSource(language: .bash, text: "printf '{\"items\":[{\"title\":\"%s\"}]}' \"$1\"")
        if let command = script.command(query: "real run", folder: URL(fileURLWithPath: NSTemporaryDirectory())) {
            let result = await ScriptRunner.run(command)
            let title = (try? ScriptFilterOutput.parse(result.output))?.items.first?.title
            check("a bash script filter runs and its JSON is read", result.succeeded && title == "real run", result.text + result.errors)
        }
        // S-045: what a real script writes to stderr reaches the debugger.
        let noisy = ScriptSource(language: .bash, text: "echo 'no name given' >&2; echo '{\"items\":[]}'")
        if let command = noisy.command(query: "", folder: URL(fileURLWithPath: NSTemporaryDirectory())),
           let workflow = library.workflow("selftest.workflow") {
            let result = await ScriptRunner.run(command)
            library.record(workflow, object: "Script Filter", input: "", result: result)
            check("a script's stderr shows in the debugger as an error",
                  library.log.shown(.errors).last?.text == "no name given", library.log.shown(.errors).last?.text ?? "none")
        }
    }

    /// S-042: the example installs and answers its keyword, Turn Off silences
    /// it, and Remove moves the folder to a stand-in Trash.
    static func checkWorkflowList(model: AppModel) async {
        let lm = model.launcherModel
        let library = WorkflowLibrary.shared
        let trash = Shared<[URL]>([])
        let realTrash = library.trash
        library.trash = { url in
            trash.value.append(url)
            try FileManager.default.removeItem(at: url)
        }
        defer {
            library.trash = realTrash
            library.selection = nil
            library.filter = ""
        }

        let before = library.workflows.count
        library.addExample()
        guard let example = library.selected else {
            check("Add Example installs Hello World and selects it", false, library.failure ?? "")
            return
        }
        check("Add Example installs Hello World and selects it", example.name == "Hello World" && library.workflows.count == before + 1)
        let placed = WorkflowLayout.positions(example)
        check("the canvas places every object where uidata says", placed.count == example.objects.count
              && placed["HELLO"] == WorkflowPoint(x: 40, y: 80))
        library.filter = "hel"
        check("Filter Workflows finds it by name", library.shown.map(\.id) == [example.id])
        library.filter = "zzz"
        check("a filter that matches nothing shows no workflow", library.shown.isEmpty)
        library.filter = ""

        lm.query = "hello Ada"
        try? await Task.sleep(for: .milliseconds(1500))
        check("its keyword answers in the launcher", lm.results.contains { $0.title == "Hello, Ada" },
              lm.results.map(\.title).joined(separator: ", "))

        library.setEnabled(false, example)
        check("Turn Off is saved in its info.plist", Workflow(folder: example.folder)?.disabled == true)
        lm.query = "hello Bob"
        try? await Task.sleep(for: .milliseconds(300))
        check("a workflow that is off adds nothing to the launcher", !lm.results.contains { $0.workflow != nil || $0.kindLabel == "Hello World" })
        library.setEnabled(true, example)

        // S-043: a saved configuration value reaches the script as an environment variable.
        if let current = library.workflow(example.id) {
            check("Configure Workflow… lists its fields", current.settings.map(\.label) == ["Greeting", "Name"])
            check("an empty required field blocks Save",
                  WorkflowConfiguration.missing(current.settings, values: ["greeting": ""]).map(\.variable) == ["greeting"])
            library.saveConfiguration(["greeting": "Hoi", "shout": "1"], for: current)
            lm.query = "hello Ada"
            try? await Task.sleep(for: .milliseconds(1500))
            check("the script reads the saved values", lm.results.contains { $0.title == "Hoi, ADA" },
                  lm.results.map(\.title).joined(separator: ", "))
        }

        // S-046: Workflow Info… saves, and Export leaves secret values out.
        if let current = library.workflow(example.id) {
            var info = WorkflowInfo(current)
            info.version = "2.0"
            info.variables = [WorkflowVariable(name: "api_key", value: "secret", dontExport: true),
                              WorkflowVariable(name: "user", value: "ada")]
            library.saveInfo(info, for: current)
            let saved = library.workflow(example.id)
            check("Workflow Info… saves the version and variables", saved?.version == "2.0"
                  && saved?.variables["api_key"] == "secret" && saved?.variables["user"] == "ada")
            let out = FileManager.default.temporaryDirectory.appending(path: "Reach-selftest-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: out) }
            try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            let file = out.appending(path: "Hello World.alfredworkflow")
            if let saved { library.export(saved, to: file) }
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzip.arguments = ["-x", "-k", file.path, out.appending(path: "x").path]
            try? unzip.run()
            unzip.waitUntilExit()
            let exported = Workflow(folder: out.appending(path: "x"))
            check("Export Workflow… blanks Don't Export values and keeps the rest",
                  exported?.variables["api_key"] == "" && exported?.variables["user"] == "ada"
                  && !FileManager.default.fileExists(atPath: out.appending(path: "x/prefs.plist").path),
                  "\(exported?.variables ?? [:]) \(library.failure ?? "")")
        }

        library.remove(library.workflow(example.id) ?? example)
        check("Remove moves the folder to the Trash", trash.value.map(\.lastPathComponent) == [example.id]
              && library.workflow(example.id) == nil && library.selection == nil)
        lm.query = ""
    }

    /// S-049: a pressed workflow hotkey runs what is connected with Alfred's
    /// argument, and a combination Reach or another hotkey has stays off.
    /// The press is injected; no real key is registered in a test run.
    private static func checkWorkflowHotkeys(model: AppModel) async {
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
    private static func checkWorkflowFileActions(model: AppModel) async {
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

    /// S-051: ↩ on a keyword runs through Split Arguments and Replace, and a
    /// File Filter lists files. Copy to Clipboard and Spotlight are fakes.
    private static func checkWorkflowUtilities(model: AppModel) async {
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
        lm.workflows.run = realRun
        check("↩ on an item sends its argument on along the grid's lines", copied.last == "copied two", copied.last ?? "none")

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
