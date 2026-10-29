import Testing
@testable import ReachKit

@Test("The prefix makes the rest a shell command")
func shellPrefix() {
    #expect(QueryKind("> ls -la", shellPrefix: ">") == .shell("ls -la"))
    #expect(QueryKind(">ls", shellPrefix: ">") == .shell("ls"))
    #expect(QueryKind(">", shellPrefix: ">") == .shell(""))
    #expect(QueryKind("$ git status", shellPrefix: "$") == .shell("git status"))
    #expect(QueryKind("> ls", shellPrefix: "$") == .normal("> ls"))
    #expect(QueryKind("> ls") == .normal("> ls"))
    #expect(QueryKind("> ls -la", shellPrefix: ">").text == "")
}

@Test("A shell prefix comes before paths and file keywords")
func shellBeforeOthers() {
    #expect(QueryKind("> /tmp", shellPrefix: ">") == .shell("/tmp"))
    #expect(QueryKind("~/", shellPrefix: ">") == .path(PathQuery("~/")!))
    #expect(QueryKind("open x", shellPrefix: ">") == .files(FileQuery(.open, "x")))
}

@Test("Quotes and backslashes are escaped for AppleScript")
func shellAppleScriptString() {
    #expect(ShellCommand.appleScriptString("ls") == "\"ls\"")
    #expect(ShellCommand.appleScriptString("echo \"hi\"") == "\"echo \\\"hi\\\"\"")
    #expect(ShellCommand.appleScriptString("a\\b") == "\"a\\\\b\"")
}

@Test("Terminal and iTerm get a script; Ghostty gets open arguments")
func shellScripts() {
    let terminal = ShellCommand.script(for: .terminal, command: "echo \"x\"")
    #expect(terminal?.contains("tell application \"Terminal\"") == true)
    #expect(terminal?.contains("do script \"echo \\\"x\\\"\"") == true)
    #expect(ShellCommand.script(for: .iTerm, command: "ls")?.contains("write text \"ls\"") == true)
    #expect(ShellCommand.script(for: .ghostty, command: "ls") == nil)
    #expect(ShellCommand.ghosttyArguments(appPath: "/Applications/Ghostty.app", command: "ls -la", shell: "/bin/zsh")
            == ["-na", "/Applications/Ghostty.app", "--args", "-e", "/bin/zsh", "-lc", "ls -la; exec /bin/zsh -l"])
}
