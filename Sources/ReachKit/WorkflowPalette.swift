import Foundation

/// One kind of object the palette offers (S-063): Alfred's type and the
/// `version` Alfred writes for it, the name on its card, and the `config` a
/// new object starts with. This list is the one home of each kind's default
/// config; the configure sheets (S-064) build on it.
public struct WorkflowKind: Identifiable, Equatable, Sendable {
    public var type: String
    public var name: String
    public var version: Int
    public var config: [String: PlistValue]

    public var id: String { type }

    public init(_ type: String, _ name: String, version: Int = 1, config: [String: PlistValue] = [:]) {
        self.type = type
        self.name = name
        self.version = version
        self.config = config
    }

    public var category: WorkflowCategory { WorkflowObject(uid: "", type: type).category }

    /// The object as it goes into info.plist's `objects`, with Alfred's keys.
    public func plist(uid: String) -> [String: Any] {
        ["uid": uid, "type": type, "version": version, "config": config.mapValues(\.plistObject)]
    }
}

/// The objects people can add to the canvas: only the kinds Reach runs, by
/// category. Versions and default configs follow what Alfred 5.5 writes for
/// a new object, so Alfred opens the workflow as if it had made them itself.
public enum WorkflowPalette {
    /// The categories in the palette's order.
    public static let categories: [WorkflowCategory] = [.trigger, .input, .action, .utility, .output]

    public static func title(_ category: WorkflowCategory) -> String {
        switch category {
        case .trigger: "Triggers"
        case .input: "Inputs"
        case .action: "Actions"
        case .utility: "Utilities"
        case .output: "Outputs"
        case .other: "Other"
        }
    }

    /// Singular, as VoiceOver reads a row: "Keyword, Input".
    public static func singular(_ category: WorkflowCategory) -> String {
        switch category {
        case .trigger: "Trigger"
        case .input: "Input"
        case .action: "Action"
        case .utility: "Utility"
        case .output: "Output"
        case .other: "Object"
        }
    }

    public static func kind(_ type: String) -> WorkflowKind? { kinds.first { $0.type == type } }

    /// The kinds by category; with a filter only the kinds whose name has a word starting with it.
    public static func sections(filter: String = "") -> [(category: WorkflowCategory, kinds: [WorkflowKind])] {
        let words = filter.lowercased().split(separator: " ")
        return categories.compactMap { category in
            let shown = kinds.filter { kind in
                kind.category == category && words.allSatisfy { word in
                    kind.name.lowercased().split { !$0.isLetter && !$0.isNumber }.contains { $0.hasPrefix(word) }
                }
            }
            return shown.isEmpty ? nil : (category, shown)
        }
    }

    // Shorthands for the configs below.
    private static func s(_ value: String) -> PlistValue { .string(value) }
    private static func i(_ value: Int) -> PlistValue { .int(value) }
    private static func b(_ value: Bool) -> PlistValue { .bool(value) }

    /// Every kind, in palette order within its category.
    public static let kinds: [WorkflowKind] = [
        // Triggers
        WorkflowKind(WorkflowHotkey.type, "Hotkey", version: 2, config: [
            "action": i(0), "argument": i(0), "focusedappvariable": b(false), "focusedappvariablename": s(""),
            "leftcursor": b(false), "modsmode": i(0), "relatedAppsMode": i(0),
        ]),
        WorkflowKind(Workflow.externalTrigger, "External Trigger", config: [
            "availableviaurlhandler": b(false), "triggerid": s(""),
        ]),
        WorkflowKind(WorkflowFallback.type, "Fallback Search", config: ["text": s("{query}")]),
        WorkflowKind(WorkflowFileAction.type, "File Action", config: [
            "acceptsmulti": i(0), "filetypes": .array([]), "name": s(""),
        ]),
        WorkflowKind(WorkflowUniversalAction.type, "Universal Action", config: [
            "acceptsfiles": b(true), "acceptsmulti": i(0), "acceptstext": b(true), "acceptsurls": b(true), "name": s(""),
        ]),
        // Inputs
        WorkflowKind(KeywordInput.type, "Keyword", config: [
            "argumenttype": i(0), "keyword": s(""), "subtext": s(""), "text": s(""), "withspace": b(true),
        ]),
        WorkflowKind(ScriptFilter.type, "Script Filter", version: 3, config: [
            "alfredfiltersresults": b(false), "alfredfiltersresultsmatchmode": i(0), "argumenttreatemptyqueryasnil": b(true),
            "argumenttrimmode": i(0), "argumenttype": i(1), "escaping": i(102), "keyword": s(""),
            "queuedelaycustom": i(3), "queuedelayimmediatelyinitially": b(true), "queuedelaymode": i(0), "queuemode": i(1),
            "runningsubtext": s(""), "script": s(""), "scriptargtype": i(1), "scriptfile": s(""), "subtext": s(""),
            "title": s(""), "type": i(11), "withspace": b(true),
        ]),
        WorkflowKind(FileFilter.type, "File Filter", version: 2, config: [
            "anchorfields": b(true), "argumenttrimmode": i(0), "argumenttype": i(0), "daterange": i(0),
            "fields": .array([
                .dict(["field": s("kMDItemDisplayName"), "not": b(false), "split": b(true), "value": s("{query}"), "words": b(true)]),
            ]),
            "includesystem": b(false), "keyword": s(""), "limit": i(0), "runningsubtext": s(""), "scopes": .array([]),
            "sortmode": i(0), "subtext": s(""), "title": s(""), "types": .array([]), "withspace": b(true),
        ]),
        // Actions
        WorkflowKind(Workflow.openURL, "Open URL", config: [
            "browser": s(""), "skipqueryencode": b(false), "skipvarencode": b(false), "spaces": s(""), "url": s(""),
        ]),
        WorkflowKind(Workflow.openFile, "Open File", version: 3, config: ["openwith": s(""), "sourcefile": s("")]),
        WorkflowKind(Workflow.revealFile, "Reveal in Finder", config: ["path": s("")]),
        WorkflowKind(Workflow.runScript, "Run Script", version: 2, config: [
            "concurrently": b(false), "escaping": i(102), "script": s(""), "scriptargtype": i(1), "scriptfile": s(""),
            "type": i(11),
        ]),
        WorkflowKind(Workflow.terminalCommand, "Terminal Command", config: ["escaping": i(0), "script": s("{query}")]),
        WorkflowKind(Workflow.browseInTerminal, "Browse in Terminal", config: ["path": s("")]),
        WorkflowKind(Workflow.actionInAlfred, "Show Actions", config: [
            "jumpto": s("_popUpItemAction:"), "path": s(""), "type": i(1),
        ]),
        // Utilities
        WorkflowKind(Workflow.argument, "Arg and Vars", config: [
            "argument": s(""), "passthroughargument": b(false), "variables": .dict([:]),
        ]),
        WorkflowKind(Workflow.conditional, "Conditional", config: [
            "conditions": .array([]), "elselabel": s("else"), "hideelse": b(false),
        ]),
        WorkflowKind(Workflow.junction, "Junction"),
        WorkflowKind(Workflow.split, "Split Arguments", config: [
            "delimiter": s(","), "discardemptyarguments": b(false), "outputas": i(1), "trimarguments": b(true),
            "variableprefix": s("split"),
        ]),
        WorkflowKind(Workflow.replace, "Replace", version: 2, config: [
            "matchmode": i(0), "matchstring": s(""), "regexcaseinsensitive": b(false), "regexmultiline": b(false),
            "replacestring": s(""),
        ]),
        WorkflowKind(Workflow.joinArgs, "Join Arguments", config: ["delimiter": s("\n")]),
        WorkflowKind(Workflow.json, "JSON Config", config: ["json": s("{\n  \"alfredworkflow\" : {\n    \"arg\" : \"{query}\"\n  }\n}")]),
        WorkflowKind(Workflow.delay, "Delay", config: ["seconds": s("1")]),
        WorkflowKind(Workflow.dialog, "Dialog", config: [
            "button1": s("OK"), "button2": s(""), "button3": s(""), "description": s(""), "title": s(""),
        ]),
        WorkflowKind(Workflow.debug, "Debug", config: [
            "argument": s("{query}"), "cleardebuggertext": b(false), "processoutputs": b(true),
        ]),
        WorkflowKind(Workflow.hideAlfred, "Hide Launcher", config: ["unstackview": b(false)]),
        // Outputs
        WorkflowKind(Workflow.copyToClipboard, "Copy to Clipboard", version: 3, config: [
            "autopaste": b(false), "clipboardtext": s("{query}"), "ignoredynamicplaceholders": b(false), "transient": b(false),
        ]),
        WorkflowKind(Workflow.largeType, "Large Type", version: 3, config: [
            "ignoredynamicplaceholders": b(false), "largetypetext": s("{query}"),
        ]),
        WorkflowKind(Workflow.notification, "Post Notification", config: [
            "lastpathcomponent": b(false), "onlyshowifquerypopulated": b(false), "removeextension": b(false),
            "text": s("{query}"), "title": s(""),
        ]),
        WorkflowKind(Workflow.playSound, "Play Sound", config: ["soundname": s("Glass"), "systemsound": b(true)]),
        WorkflowKind(Workflow.callExternalTrigger, "Call External Trigger", config: [
            "externaltriggerid": s(""), "passinputasargument": b(true), "passvariables": b(true), "workflowbundleid": s("self"),
        ]),
        WorkflowKind(Workflow.dispatchKeys, "Dispatch Key Combo", config: [
            "count": i(1), "keychar": s("v"), "keycode": i(-1), "keymod": i(WorkflowConnection.command),
            "overridewithargument": b(false),
        ]),
    ]
}

extension PlistValue {
    /// The value as PropertyListSerialization writes it.
    public var plistObject: Any {
        switch self {
        case .string(let value): value
        case .int(let value): value
        case .double(let value): value
        case .bool(let value): value
        case .date(let value): value
        case .data(let value): value
        case .array(let value): value.map(\.plistObject)
        case .dict(let value): value.mapValues(\.plistObject)
        }
    }
}
