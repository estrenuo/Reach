import Foundation

/// The Finder automation tasks (S-055), each an AppleScript through `osascript`
/// whose output goes on to the next objects. Asking Finder needs the
/// Automation permission; a refusal shows as the script's error in the debugger.
public enum FinderTask {
    static let prefix = "com.alfredapp.automation.core/files-and-folders/"
    /// The selected files in Finder, tab-separated as Alfred passes files.
    public static let selection = prefix + "finder.selection"
    /// The folder of the front Finder window, empty when no window is open.
    public static let currentWindow = prefix + "finder.windows.current"

    static let scripts = [
        selection: """
            tell application "Finder" to set picked to selection as alias list
            set paths to {}
            repeat with item_ in picked
                set end of paths to POSIX path of item_
            end repeat
            set AppleScript's text item delimiters to tab
            return paths as text
            """,
        currentWindow: """
            tell application "Finder"
                if (count of Finder windows) is 0 then return ""
                try
                    return POSIX path of (target of front Finder window as alias)
                on error
                    return ""
                end try
            end tell
            """,
    ]

    /// The command for the task `taskuid`, nil when it is not a Finder task Reach knows.
    public static func command(for taskuid: String, folder: URL, environment: [String: String]) -> ScriptCommand? {
        scripts[taskuid].map { ScriptCommand(executable: "/usr/bin/osascript", arguments: ["-e", $0], directory: folder, environment: environment) }
    }
}
