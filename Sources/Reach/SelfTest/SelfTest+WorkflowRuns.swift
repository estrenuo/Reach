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
        let plist = selfTestWorkflowPlist()
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
}
