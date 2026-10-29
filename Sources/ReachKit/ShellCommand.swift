import Foundation

/// The app a shell command runs in (S-021). Only installed ones are offered.
public enum TerminalApp: String, CaseIterable, Codable, Sendable {
    case terminal, ghostty, iTerm

    public var title: String {
        switch self {
        case .terminal: "Terminal"
        case .ghostty: "Ghostty"
        case .iTerm: "iTerm"
        }
    }

    public var bundleID: String {
        switch self {
        case .terminal: "com.apple.Terminal"
        case .ghostty: "com.mitchellh.ghostty"
        case .iTerm: "com.googlecode.iterm2"
        }
    }
}

/// `> ls -la`: a prefix, then a command that runs in a new terminal window.
public enum ShellCommand {
    /// The characters the prefix can be, as in Alfred. None starts a word,
    /// so a prefix never takes a keyword or an app name.
    public static let prefixes = [">", "$", "!", ";", "#"]
    public static let standardPrefix = ">"

    /// The command after `prefix`, trimmed; empty for the prefix alone.
    /// Nil when the query does not start with the prefix.
    public static func command(in query: String, prefix: String) -> String? {
        guard !prefix.isEmpty, query.hasPrefix(prefix) else { return nil }
        return query.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
    }

    /// `text` as an AppleScript string literal, quotes and backslashes escaped.
    public static func appleScriptString(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// The AppleScript that opens a new window running `command`, for the
    /// apps that take one. The shell stays open after the command ends.
    public static func script(for app: TerminalApp, command: String) -> String? {
        let text = appleScriptString(command)
        switch app {
        case .terminal:
            return """
            tell application "Terminal"
                activate
                do script \(text)
            end tell
            """
        case .iTerm:
            return """
            tell application "iTerm"
                activate
                set newWindow to (create window with default profile)
                tell current session of newWindow to write text \(text)
            end tell
            """
        case .ghostty:
            return nil
        }
    }

    /// The `open` arguments for Ghostty, which takes a command at launch
    /// instead of AppleScript. The login shell runs it, then stays open.
    public static func ghosttyArguments(appPath: String, command: String, shell: String) -> [String] {
        ["-na", appPath, "--args", "-e", shell, "-lc", "\(command); exec \(shell) -l"]
    }
}
