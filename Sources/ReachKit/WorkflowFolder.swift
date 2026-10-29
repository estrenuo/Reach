import Foundation

/// Changes to the workflow folders on disk (S-042): install, switch off,
/// remove, and a first example. Each change edits the folder's info.plist,
/// so the folder stays a workflow Alfred can read too.
public enum WorkflowFolder {
    public enum Failure: Error, Equatable {
        /// The chosen folder has no info.plist.
        case notAWorkflow
    }

    /// A new folder name in Alfred's style: `user.workflow.<UUID>`.
    public static func newName() -> String { "user.workflow." + UUID().uuidString }

    /// Reads info.plist, lets `change` edit it and writes it back as XML.
    public static func update(_ folder: URL, _ change: (inout [String: Any]) -> Void) throws {
        let url = folder.appending(path: Workflow.infoFile)
        let data = try Data(contentsOf: url)
        var plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] ?? [:]
        change(&plist)
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: url, options: .atomic)
    }

    /// Switches the workflow off or on: its keywords stop or start answering.
    public static func setDisabled(_ disabled: Bool, folder: URL) throws {
        try update(folder) { $0["disabled"] = disabled }
    }

    /// Moves the folder to the Trash, so a removed workflow can be put back.
    public static func remove(_ folder: URL, trash: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) throws {
        try trash(folder)
    }

    /// Copies a workflow folder into `library` under a new name; the original stays where it was.
    @discardableResult
    public static func install(from source: URL, into library: URL) throws -> URL {
        guard FileManager.default.fileExists(atPath: source.appending(path: Workflow.infoFile).path) else { throw Failure.notAWorkflow }
        try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        let target = library.appending(path: newName(), directoryHint: .isDirectory)
        try FileManager.default.copyItem(at: source, to: target)
        return target
    }

    /// A small workflow to start from: `hello` and a name says hello back.
    @discardableResult
    public static func addExample(into library: URL) throws -> URL {
        let target = library.appending(path: newName(), directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let script = """
        name="${1:-world}"
        word="${greeting:-Hello}"
        [ "$shout" = "1" ] && name="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"
        cat <<JSON
        {"items": [
          {"title": "$word, $name", "subtitle": "Return copies the greeting", "arg": "$word, $name"},
          {"title": "Search the web for $name", "subtitle": "⌘↩ opens the search", "arg": "$name",
           "mods": {"cmd": {"subtitle": "Open a web search for $name"}}}
        ]}
        JSON
        """
        let plist: [String: Any] = [
            "bundleid": "", "name": "Hello World", "createdby": "Reach", "version": "1.0",
            "description": "Says hello: an example to copy.",
            "readme": "Type **hello** and a name. Return copies the greeting; ⌘↩ searches the web for the name.\n\nThe script is bash. It prints Script Filter JSON: one item per row. Configure Workflow… sets the greeting, which the script reads as `$greeting`.",
            "userconfigurationconfig": [
                ["type": "textfield", "variable": "greeting", "label": "Greeting",
                 "description": "The word before the name.", "config": ["default": "Hello", "required": true, "placeholder": "Hello"]],
                ["type": "checkbox", "variable": "shout", "label": "Name",
                 "description": "", "config": ["default": false, "text": "Write the name in capitals"]],
            ] as [[String: Any]],
            "objects": [
                ["uid": "HELLO", "type": ScriptFilter.type, "config": [
                    "keyword": "hello", "withspace": true, "argumenttype": 1, "title": "Say hello",
                    "subtext": "Type a name", "runningsubtext": "Saying hello…", "script": script, "type": 0,
                    "scriptargtype": 1, "escaping": 102,
                ] as [String: Any]],
                ["uid": "COPY", "type": Workflow.copyToClipboard, "config": ["clipboardtext": "{query}"]],
                ["uid": "WEB", "type": Workflow.openURL, "config": ["url": "https://duckduckgo.com/?q={query}"]],
            ],
            "connections": ["HELLO": [
                ["destinationuid": "COPY", "modifiers": 0],
                ["destinationuid": "WEB", "modifiers": WorkflowConnection.command, "modifiersubtext": "Open a web search"],
            ]],
            "uidata": [
                "HELLO": ["xpos": 40, "ypos": 80],
                "COPY": ["xpos": 300, "ypos": 20],
                "WEB": ["xpos": 300, "ypos": 160],
            ],
        ]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: target.appending(path: Workflow.infoFile))
        return target
    }

    /// True when `filter` is empty or starts a word of the name, the author or a keyword.
    public static func matches(_ workflow: Workflow, filter: String) -> Bool {
        let words = filter.lowercased().split(separator: " ")
        guard !words.isEmpty else { return true }
        let text = ([workflow.name, workflow.author] + workflow.scriptFilters.map(\.keyword)).joined(separator: " ").lowercased()
        let parts = text.split { !$0.isLetter && !$0.isNumber }
        return words.allSatisfy { word in parts.contains { $0.hasPrefix(word) } }
    }
}
