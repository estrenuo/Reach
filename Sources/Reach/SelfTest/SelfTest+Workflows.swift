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
            ],
            "connections": ["SF": [
                ["destinationuid": "URL", "modifiers": 0],
                ["destinationuid": "COPY", "modifiers": WorkflowConnection.command, "modifiersubtext": "Copy"],
            ]],
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
        launcher.hide()

        // The real runner: a bash script gets the text as $1 and its output parses.
        let script = ScriptSource(language: .bash, text: "printf '{\"items\":[{\"title\":\"%s\"}]}' \"$1\"")
        if let command = script.command(query: "real run", folder: URL(fileURLWithPath: NSTemporaryDirectory())) {
            let result = await ScriptRunner.run(command)
            let title = (try? ScriptFilterOutput.parse(result.output))?.items.first?.title
            check("a bash script filter runs and its JSON is read", result.succeeded && title == "real run", result.text + result.errors)
        }
    }
}
