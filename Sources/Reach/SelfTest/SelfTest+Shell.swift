import AppKit
import ReachKit

extension SelfTest {
    /// S-021: the prefix makes one row that runs the command in the terminal
    /// app. Every run goes to a recorder, so no command ever runs.
    static func checkShell(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let settings = TerminalSettings.shared
        var ran: [ShellRun] = []
        var learned = 0
        let onOpened = lm.onOpened
        lm.runShell = { ran.append($0); return true }
        lm.onOpened = { query, result in learned += 1; onOpened(query, result) }
        defer {
            settings.reset()
            lm.runShell = { _ in true }
            lm.onOpened = onOpened
        }

        launcher.show()
        lm.query = "> ls -la"
        check("the prefix shows one row “Run command in Terminal”", lm.results.count == 1
              && lm.results.first?.title == "Run command in Terminal", lm.results.map(\.title).joined(separator: ", "))
        lm.openSelected()
        check("↩ runs the command in Terminal and hides the launcher",
              ran == [ShellRun(command: "ls -la", app: .terminal)] && !launcher.isVisible)
        check("a shell command is not learned", learned == 0)

        launcher.show()
        lm.query = ">"
        check("the prefix alone asks for a command", lm.results.count == 1
              && lm.results.first?.title == ShellSource.hint && lm.results.first?.isOpenable == false)

        settings.prefix = "$"
        lm.query = "> ls"
        check("the old prefix is a normal search again", !lm.results.contains { $0.shell != nil })
        lm.query = "$ git status"
        check("a changed prefix is saved and starts a shell command",
              Store.settings.string(forKey: "terminal.prefix") == "$" && lm.results.first?.shell?.command == "git status")

        settings.app = .ghostty
        lm.query = "$ top"
        check("the chosen app names the row and runs the command",
              lm.results.first?.title == "Run command in Ghostty" && Store.settings.string(forKey: "terminal.app") == "ghostty")
        lm.openSelected()
        check("↩ runs it in Ghostty", ran.last == ShellRun(command: "top", app: .ghostty))

        launcher.show()
        settings.app = .terminal
        lm.runShell = { _ in false }
        lm.query = "$ ls"
        lm.openSelected()
        check("a terminal that does not open says so under the row", lm.errors["shell"] == "Unable to open Terminal."
              && launcher.isVisible)
        launcher.hide()
    }
}
