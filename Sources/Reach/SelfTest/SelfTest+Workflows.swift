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
                ["uid": "TRASHKW", "type": KeywordInput.type, "config": ["keyword": "rtrash", "argumenttype": 0, "text": "Trash"]],
                ["uid": "TRASH", "type": Workflow.automationTask, "config": [
                    "taskuid": Workflow.trashTask, "tasksettings": ["target_path": "/tmp/{query}"],
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
        launcher.hide()

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
}
