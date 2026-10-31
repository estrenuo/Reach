import Foundation

/// The Shortcuts objects (S-055): Run Shortcut and the View Shortcut task,
/// both through `/usr/bin/shortcuts`, so the next objects get what it prints.
public enum WorkflowShortcut {
    public static let runType = "alfred.workflow.automation.runshortcut"
    public static let viewTask = "com.alfredapp.automation.core/shortcuts/shortcut.view"
    static let tool = "/usr/bin/shortcuts"

    /// Runs the shortcut named in `shortcut`. `inputmode` -1 gives it nothing,
    /// 0 the text, 1 the files (tab-separated paths). Only `outputmode` 0 is mapped.
    public static func run(_ object: WorkflowObject, argument: String, variables: [String: String],
                           folder: URL, environment: [String: String]) -> Result<ScriptCommand, WorkflowProblem> {
        let name = WorkflowText.fill(object.string("shortcut"), query: argument, variables: variables)
        guard !name.isEmpty else { return .failure(WorkflowProblem(kind: "automation.runshortcut without a shortcut")) }
        guard object.int("outputmode") == 0 else {
            return .failure(WorkflowProblem(kind: "automation.runshortcut with outputmode \(object.int("outputmode"))"))
        }
        switch object.int("inputmode", default: -1) {
        case -1:
            return .success(ScriptCommand(executable: tool, arguments: ["run", name], directory: folder, environment: environment))
        case 0:
            // Shortcuts takes input from files only: the text goes in a temporary
            // one. Name and text are arguments, never part of the script.
            let script = #"d=$(mktemp -d); printf %s "$2" > "$d/input.txt"; "#
                + #"\#(tool) run "$1" -i "$d/input.txt"; s=$?; rm -rf "$d"; exit $s"#
            return .success(ScriptCommand(executable: "/bin/zsh", arguments: ["-c", script, "zsh", name, argument],
                                          directory: folder, environment: environment))
        case 1:
            let paths = argument.split(separator: "\t").map(String.init)
            return .success(ScriptCommand(executable: tool, arguments: ["run", name] + (paths.isEmpty ? [] : ["-i"] + paths),
                                          directory: folder, environment: environment))
        case let mode:
            return .failure(WorkflowProblem(kind: "automation.runshortcut with inputmode \(mode)"))
        }
    }

    /// Opens the shortcut in `target_shortcut` (else the text) in the Shortcuts app.
    public static func view(_ object: WorkflowObject, argument: String, variables: [String: String],
                            folder: URL, environment: [String: String]) -> ScriptCommand {
        let target = object.config["tasksettings"]?.dict?["target_shortcut"]?.string ?? ""
        let name = target.isEmpty ? argument : WorkflowText.fill(target, query: argument, variables: variables)
        return ScriptCommand(executable: tool, arguments: ["view", name], directory: folder, environment: environment)
    }
}
