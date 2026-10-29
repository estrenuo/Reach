import AppKit
import ReachKit

/// Settings > Terminal (S-021): the prefix that marks a shell command and
/// the app it runs in. Saved in `Store.settings`.
@Observable
final class TerminalSettings {
    static let shared = TerminalSettings()
    private static let prefixKey = "terminal.prefix"
    private static let appKey = "terminal.app"

    var prefix: String {
        didSet { Store.settings.set(prefix, forKey: Self.prefixKey) }
    }
    var app: TerminalApp {
        didSet { Store.settings.set(app.rawValue, forKey: Self.appKey) }
    }

    private init() {
        let saved = Store.settings.string(forKey: Self.prefixKey)
        prefix = saved.flatMap { ShellCommand.prefixes.contains($0) ? $0 : nil } ?? ShellCommand.standardPrefix
        app = Store.settings.string(forKey: Self.appKey).flatMap(TerminalApp.init(rawValue:)) ?? .terminal
    }

    /// The apps the menu offers: Terminal, and the others that are installed.
    /// The chosen one stays listed, so the menu never shows a blank.
    var offered: [TerminalApp] {
        TerminalApp.allCases.filter { $0 == .terminal || $0 == app || Self.path(of: $0) != nil }
    }

    static func path(of app: TerminalApp) -> String? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID)?.path
    }

    /// Back to `>` and Terminal; the self-test leaves no trace this way.
    func reset() {
        prefix = ShellCommand.standardPrefix
        app = .terminal
    }
}

/// What Return does for a shell command: run it in this app.
struct ShellRun: Equatable {
    var command: String
    var app: TerminalApp
}

/// `> ls -la`: one row that runs the command in the terminal app (S-021).
/// The prefix alone shows a hint, as `=` does for the calculator.
final class ShellSource: ResultSource {
    static let hint = "Type a shell command"
    let settings: TerminalSettings

    init(settings: TerminalSettings = .shared) {
        self.settings = settings
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .shell(let command) = query else { return [] }
        let app = settings.app
        let icon = TerminalSettings.path(of: app).map { LaunchResult.Icon.file($0) } ?? .symbol("apple.terminal")
        guard !command.isEmpty else {
            return [Scored(result: LaunchResult(id: "hint:shell", title: Self.hint, subtitle: "", icon: icon, url: nil), score: 0)]
        }
        return [Scored(result: LaunchResult(id: "shell", title: "Run command in \(app.title)",
                                            subtitle: "Opens a new window and runs it", icon: icon, url: nil,
                                            kindLabel: "Shell command", isPinned: true,
                                            shell: ShellRun(command: command, app: app)), score: 0)]
    }
}

/// Opens a new window in the terminal app and runs the command there.
/// The command is never logged: it can hold paths and passwords.
enum ShellRunner {
    static func run(_ run: ShellRun) -> Bool {
        systemLog.notice("shell in \(run.app.rawValue, privacy: .public)")
        if let source = ShellCommand.script(for: run.app, command: run.command) {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error { systemLog.error("shell script failed: \(error[NSAppleScript.errorNumber] as? Int ?? 0, privacy: .public)") }
            return error == nil
        }
        guard let path = TerminalSettings.path(of: run.app) else { return false }
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ShellCommand.ghosttyArguments(appPath: path, command: run.command, shell: shell)
        return (try? process.run()) != nil
    }
}
