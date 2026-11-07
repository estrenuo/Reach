import Foundation

/// One field of an object's settings sheet (S-064): one key of its `config`.
public struct WorkflowField: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case text
        /// Several lines; `code` shows them in a monospaced font.
        case lines(code: Bool)
        case toggle
        case number
        case choice([Choice])
        /// A list or a dictionary, edited as JSON.
        case structured
    }

    public struct Choice: Equatable, Sendable, Hashable {
        public var value: Int
        public var title: String
    }

    public var key: String
    public var label: String
    public var kind: Kind

    public var id: String { key }
}

/// The settings sheet of each kind the palette offers (S-064). Every field
/// is one key of the kind's default `config` in `WorkflowPalette`, and every
/// key there has a field. Keys an object has beyond those stay as they are.
public enum WorkflowForm {
    /// The fields for objects of `type`, most used first; empty for a kind Reach cannot configure.
    public static func fields(_ type: String) -> [WorkflowField] {
        guard let kind = WorkflowPalette.kind(type) else { return [] }
        let keys = kind.config.keys.sorted { a, b in
            let (ia, ib) = (order.firstIndex(of: a) ?? .max, order.firstIndex(of: b) ?? .max)
            return ia != ib ? ia < ib : a < b
        }
        return keys.map { key in
            WorkflowField(key: key, label: label(key, type: type), kind: fieldKind(key, type: type, value: kind.config[key]!))
        }
    }

    /// The values the sheet opens with: the object's own, else the kind's default.
    public static func values(_ object: WorkflowObject) -> [String: PlistValue] {
        guard let kind = WorkflowPalette.kind(object.type) else { return [:] }
        return kind.config.merging(object.config.filter { kind.config[$0.key] != nil }) { _, own in own }
    }

    /// A list or dictionary as the JSON its field shows.
    public static func json(_ value: PlistValue) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value.plistObject,
                                                     options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes])
        else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    public enum Failure: Error, Equatable {
        /// The JSON of a list or dictionary field does not read, or has the wrong shape.
        case notJSON(label: String)
    }

    /// The JSON typed in a list or dictionary field, as a value of the same shape as `like`.
    public static func value(json: String, like: PlistValue, label: String) throws -> PlistValue {
        let text = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let object = try? JSONSerialization.jsonObject(with: Data((text.isEmpty ? (like.isDict ? "{}" : "[]") : text).utf8),
                                                             options: [.fragmentsAllowed]),
              let value = PlistValue(object), value.isDict == like.isDict, value.isArray == like.isArray
        else { throw Failure.notJSON(label: label) }
        return value
    }

    // MARK: - Labels and kinds

    /// The keys people change most, in the order the sheet shows them; the rest follow by name.
    static let order = [
        "keyword", "withspace", "argumenttype", "title", "text", "subtext", "runningsubtext", "url", "type", "scriptargtype",
        "script", "scriptfile", "escaping", "clipboardtext", "largetypetext", "path", "sourcefile", "openwith", "name",
        "triggerid", "externaltriggerid", "workflowbundleid", "argument", "variables", "delimiter", "matchmode", "matchstring",
        "replacestring", "json", "seconds", "button1", "button2", "button3", "description", "conditions", "elselabel",
        "fields", "scopes", "types", "filetypes", "soundname", "keychar",
    ]

    private static let labels: [String: String] = [
        "keyword": "Keyword", "withspace": "With Space", "argumenttype": "Argument", "title": "Title", "text": "Text",
        "subtext": "Subtext", "runningsubtext": "Please Wait Subtext", "url": "URL", "type": "Language",
        "scriptargtype": "Input", "script": "Script", "scriptfile": "Script File", "escaping": "Escaping",
        "clipboardtext": "Text", "largetypetext": "Text", "path": "Path", "sourcefile": "File", "openwith": "Open With",
        "name": "Name", "triggerid": "Trigger ID", "externaltriggerid": "Trigger ID", "workflowbundleid": "Workflow Bundle ID",
        "argument": "Argument", "variables": "Variables", "delimiter": "Delimiter", "matchmode": "Match Mode",
        "matchstring": "Replace", "replacestring": "With", "json": "JSON", "seconds": "Seconds", "button1": "Button 1",
        "button2": "Button 2", "button3": "Button 3", "description": "Description", "conditions": "Conditions",
        "elselabel": "Else Label", "hideelse": "Hide Else", "fields": "Search Fields", "scopes": "Search Scope",
        "types": "File Types", "filetypes": "File Types", "soundname": "Sound", "systemsound": "System Sound",
        "keychar": "Key", "keycode": "Key Code", "keymod": "Modifiers", "count": "Repeat", "overridewithargument": "Use Argument Instead",
        "action": "Action", "focusedappvariable": "Set Focused App Variable", "focusedappvariablename": "Focused App Variable",
        "leftcursor": "Cursor at Left", "modsmode": "Modifiers Mode", "relatedAppsMode": "Related Apps",
        "availableviaurlhandler": "Available via URL Handler", "acceptsmulti": "Multiple Items", "acceptsfiles": "Accept Files",
        "acceptstext": "Accept Text", "acceptsurls": "Accept URLs", "alfredfiltersresults": "Let Reach Filter Results",
        "alfredfiltersresultsmatchmode": "Filter Match Mode", "argumenttreatemptyqueryasnil": "Empty Query as No Argument",
        "argumenttrimmode": "Trim Argument", "queuedelaycustom": "Custom Delay", "queuedelayimmediatelyinitially": "Run at Once on First Character",
        "queuedelaymode": "Delay Mode", "queuemode": "Queue", "anchorfields": "Anchor Fields", "daterange": "Date Range",
        "includesystem": "Include System Files", "limit": "Limit", "sortmode": "Sort", "browser": "Browser",
        "skipqueryencode": "Don't Encode the Query", "skipvarencode": "Don't Encode Variables", "spaces": "Spaces As",
        "concurrently": "Run Concurrently", "jumpto": "Jump To", "passthroughargument": "Keep the Argument",
        "discardemptyarguments": "Discard Empty Arguments", "outputas": "Output As", "trimarguments": "Trim Arguments",
        "variableprefix": "Variable Prefix", "regexcaseinsensitive": "Ignore Case", "regexmultiline": "Multiline",
        "cleardebuggertext": "Clear the Debugger", "processoutputs": "Pass the Output On", "unstackview": "Unstack the View",
        "autopaste": "Paste to Front App", "ignoredynamicplaceholders": "Ignore Dynamic Placeholders",
        "transient": "Keep Out of Clipboard History", "lastpathcomponent": "Last Path Component Only",
        "onlyshowifquerypopulated": "Only Show When There Is Text", "removeextension": "Remove Extension",
        "passinputasargument": "Pass Input as Argument", "passvariables": "Pass Variables",
    ]

    private static func label(_ key: String, type: String) -> String {
        if key == "type", type == Workflow.actionInAlfred { return "Show" }
        if key == "text", type == KeywordInput.type || type == WorkflowFallback.type { return "Title" }
        if key == "title", type == Workflow.notification || type == Workflow.dialog { return "Title" }
        if key == "text", type == Workflow.notification { return "Text" }
        if key == "script", type == Workflow.terminalCommand { return "Command" }
        return labels[key] ?? key.prefix(1).uppercased() + key.dropFirst()
    }

    private static let languages: [WorkflowField.Choice] = [
        .init(value: 0, title: "/bin/bash"), .init(value: 5, title: "/bin/zsh"), .init(value: 11, title: "/bin/zsh --no-rcs"),
        .init(value: 9, title: "/usr/bin/python3"), .init(value: 2, title: "/usr/bin/ruby"), .init(value: 4, title: "/usr/bin/perl"),
        .init(value: 1, title: "/usr/bin/php"), .init(value: 6, title: "/usr/bin/osascript (AppleScript)"),
        .init(value: 7, title: "/usr/bin/osascript (JavaScript)"), .init(value: 8, title: "External Script"),
    ]

    private static func fieldKind(_ key: String, type: String, value: PlistValue) -> WorkflowField.Kind {
        switch value {
        case .bool: return .toggle
        case .array, .dict: return .structured
        case .int, .double:
            if key == "type", [ScriptFilter.type, Workflow.runScript].contains(type) { return .choice(languages) }
            if key == "argumenttype" {
                return .choice([.init(value: 0, title: "Required"), .init(value: 1, title: "Optional"), .init(value: 2, title: "No Argument")])
            }
            if key == "scriptargtype" {
                return .choice([.init(value: 0, title: "with input as {query}"), .init(value: 1, title: "with input as argv")])
            }
            if key == "queuemode" {
                return .choice([.init(value: 1, title: "Wait for the previous run"), .init(value: 2, title: "Stop the previous run")])
            }
            return .number
        default:
            if ["script", "json"].contains(key) { return .lines(code: true) }
            if ["clipboardtext", "largetypetext", "description"].contains(key) { return .lines(code: false) }
            return .text
        }
    }
}

extension PlistValue {
    var isDict: Bool { if case .dict = self { true } else { false } }
    var isArray: Bool { if case .array = self { true } else { false } }
}

extension WorkflowEdit {
    /// The `config` of object `uid` as info.plist has it, with every key.
    public static func config(_ uid: String, in plist: [String: Any]) -> [String: Any]? {
        (plist["objects"] as? [[String: Any]])?.first { $0["uid"] as? String == uid }?["config"] as? [String: Any]
    }

    /// Sets `values` in object `uid`'s `config`; its other keys stay as they are.
    public static func configure(_ uid: String, values: [String: PlistValue], in plist: inout [String: Any]) {
        replaceConfig(uid, in: &plist) { config in
            for (key, value) in values { config[key] = value.plistObject }
        }
    }

    /// Puts back a whole `config` as it was (Undo Configure Object).
    public static func setConfig(_ uid: String, _ config: [String: Any], in plist: inout [String: Any]) {
        replaceConfig(uid, in: &plist) { $0 = config }
    }

    private static func replaceConfig(_ uid: String, in plist: inout [String: Any], _ change: (inout [String: Any]) -> Void) {
        guard var objects = plist["objects"] as? [[String: Any]],
              let index = objects.firstIndex(where: { $0["uid"] as? String == uid }) else { return }
        var config = objects[index]["config"] as? [String: Any] ?? [:]
        change(&config)
        objects[index]["config"] = config
        plist["objects"] = objects
    }
}
