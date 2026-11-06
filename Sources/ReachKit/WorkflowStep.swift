import Foundation

/// What Return on a workflow row does (S-041): the objects connected to the
/// script filter, turned into steps the app runs. Reach runs a few kinds of
/// object; the others become `unsupported`, so the debugger can say so.
public enum WorkflowStep: Equatable, Sendable {
    /// Open a URL, or a file when the text is a path.
    case open(String)
    case reveal(String)
    case copy(String)
    case largeType(String)
    /// Run a script; its output goes on to the objects after `then`, with
    /// `variables` (S-047).
    case run(ScriptCommand, then: String, variables: [String: String])
    /// Show the launcher with this text typed: an External Trigger that leads
    /// back to a script filter or keyword (S-047).
    case show(String)
    /// Move a file to the Trash: the Automation Task `path.trash` (S-047).
    case trash(String)
    /// Post a notification with this title and text (S-048).
    case notify(title: String, text: String)
    /// Play a system sound by name, or a sound file by its path (S-048).
    case sound(String)
    /// Write a line to the workflow debugger, after clearing it when `clear` (S-048).
    case debug(String, clear: Bool)
    /// Open the terminal in this folder, or the folder of this file (S-053).
    case terminal(String)
    /// Run this command in a new window of the terminal app from Settings > Terminal (S-055).
    case terminalCommand(String)
    /// Show this text in a window named after the workflow (S-055).
    case textView(String)
    /// Show an alert with this title, text and buttons (S-055).
    case dialog(title: String, text: String, buttons: [String])
    /// Wait `seconds`, then go on after `then` with the argument (S-055).
    case wait(seconds: Double, then: String, argument: String, variables: [String: String], environment: [String: String])
    /// Open the action panel for this path, or for this text when it is not one (S-054).
    case actions(String)
    /// Read the front browser tab's URL, then go on after `then` with it (S-054).
    /// `allowEmpty`: go on with an empty argument when there is no tab.
    case currentTab(then: String, allowEmpty: Bool, variables: [String: String], environment: [String: String])
    /// Show the items a Grid View's script prints in the launcher (S-053).
    case grid(WorkflowGridRun)
    /// Press keys in the app in front, after the launcher hides (S-053).
    case keys(WorkflowKeys)
    /// An object Reach does not run, by its kind, like `automation.task`.
    case unsupported(String)
}

extension Workflow {
    public static let openURL = "alfred.workflow.action.openurl"
    public static let openFile = "alfred.workflow.action.openfile"
    public static let revealFile = "alfred.workflow.action.revealfile"
    public static let runScript = "alfred.workflow.action.script"
    public static let copyToClipboard = "alfred.workflow.output.clipboard"
    public static let largeType = "alfred.workflow.output.largetype"
    public static let junction = "alfred.workflow.utility.junction"
    public static let argument = "alfred.workflow.utility.argument"
    public static let conditional = "alfred.workflow.utility.conditional"
    public static let hideAlfred = "alfred.workflow.utility.hidealfred"
    public static let externalTrigger = "alfred.workflow.trigger.external"
    public static let callExternalTrigger = "alfred.workflow.output.callexternaltrigger"
    public static let automationTask = "alfred.workflow.automation.task"
    public static let notification = "alfred.workflow.output.notification"
    public static let playSound = "alfred.workflow.output.playsound"
    public static let debug = "alfred.workflow.utility.debug"
    public static let split = "alfred.workflow.utility.split"
    public static let replace = "alfred.workflow.utility.replace"
    public static let json = "alfred.workflow.utility.json"
    public static let joinArgs = "alfred.workflow.utility.joinargs"
    public static let browseInTerminal = "alfred.workflow.action.browseinterminal"
    public static let dispatchKeys = "alfred.workflow.output.dispatchkeycombo"
    public static let grid = "alfred.workflow.userinterface.grid"
    public static let actionInAlfred = "alfred.workflow.action.actioninalfred"
    public static let delay = "alfred.workflow.utility.delay"
    public static let dialog = "alfred.workflow.utility.dialog"
    public static let terminalCommand = "alfred.workflow.action.terminalcommand"
    public static let textView = "alfred.workflow.userinterface.text"
    /// The Automation Task that moves a path to the Trash.
    public static let trashTask = "com.alfredapp.automation.core/files-and-folders/path.trash"
    /// How many objects one Return follows at most, so a loop of triggers ends.
    static let deepest = 32

    /// The steps for the objects connected to `uid` with `modifiers` held.
    /// With nothing connected, a URL or a path is opened.
    public func steps(after uid: String, argument: String, modifiers: Int = 0,
                      variables: [String: String] = [:], environment: [String: String] = [:]) -> [WorkflowStep] {
        let all = connections[uid] ?? []
        if all.isEmpty, let type = object(uid)?.type, [ScriptFilter.type, KeywordInput.type].contains(type) {
            return Self.opensItself(argument) ? [.open(argument)] : []
        }
        return follow(all.filter { $0.modifiers == modifiers },
                      WorkflowFlow(argument: argument, variables: variables, environment: environment))
    }

    /// The steps after `uid` without a modifier, on the lines that leave `output`.
    func next(after uid: String, output: String? = nil, _ flow: WorkflowFlow) -> [WorkflowStep] {
        let lines = (connections[uid] ?? []).filter { $0.modifiers == 0 && $0.sourceOutput == output }
        var flow = flow
        flow.depth += 1
        return follow(lines, flow)
    }

    func follow(_ lines: [WorkflowConnection], _ flow: WorkflowFlow) -> [WorkflowStep] {
        guard flow.depth < Self.deepest else { return [] }
        return lines.flatMap { line -> [WorkflowStep] in
            guard var object = object(line.to) else { return [] }
            object.config.merge(flow.config) { _, new in new }
            var flow = flow
            flow.config = [:]
            return actionSteps(object, flow) ?? outputSteps(object, flow) ?? utilitySteps(object, flow)
                ?? taskSteps(object, flow)
                ?? [.unsupported(object.type.replacingOccurrences(of: "alfred.workflow.", with: ""))]
        }
    }

    /// The variables as the debugger shows them: `{name = value, …}`, by name.
    static func describe(_ variables: [String: String]) -> String {
        "{" + variables.sorted { $0.key < $1.key }.map { "\($0.key) = \($0.value)" }.joined(separator: ", ") + "}"
    }

    static func opensItself(_ text: String) -> Bool {
        text.hasPrefix("/") || text.hasPrefix("~/") || (URL(string: text)?.scheme.map { !$0.isEmpty } ?? false)
    }
}

/// Fills `{query}` and `{var:name}` in an object's text.
public enum WorkflowText {
    /// Fills `{query}` and `{var:name}` in one pass over `text`, so a value
    /// that holds `{var:…}` itself is never expanded again.
    public static func fill(_ text: String, query: String, variables: [String: String] = [:], encodeQuery: Bool = false) -> String {
        let value = encodeQuery ? (query.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? query) : query
        var result = ""
        var rest = text[...]
        while let open = rest.firstIndex(of: "{") {
            result += rest[..<open]
            let token = rest[open...]
            if token.hasPrefix("{query}") {
                result += value
                rest = token.dropFirst("{query}".count)
            } else if token.hasPrefix("{var:"), let close = token.firstIndex(of: "}"),
                      let variable = variables[String(token[token.index(open, offsetBy: 5)..<close])] {
                result += variable
                rest = token[token.index(after: close)...]
            } else {
                result += "{"
                rest = token.dropFirst()
            }
        }
        return result + rest
    }
}

/// A Conditional utility (S-047): its conditions in order, each comparing its
/// input (the `{query}` when empty) with a match string. Alfred's help lists
/// modes 0 to 4; 5 and 6 are read from workflows that use them on values like
/// "1" and "0" or true and false. Any other mode never matches.
public enum WorkflowCondition {
    /// The uid of the first condition that matches, or nil for the else line.
    public static func output(of object: WorkflowObject, query: String, variables: [String: String]) -> String? {
        for condition in object.config["conditions"]?.array ?? [] {
            guard let dict = condition.dict else { continue }
            let text = { (key: String) in dict[key]?.string ?? "" }
            let input = text("inputstring").isEmpty ? query : WorkflowText.fill(text("inputstring"), query: query, variables: variables)
            let match = WorkflowText.fill(text("matchstring"), query: query, variables: variables)
            if matches(input, match, mode: dict["matchmode"]?.int ?? 0, caseSensitive: dict["matchcasesensitive"]?.bool ?? false) {
                return text("uid")
            }
        }
        return nil
    }

    public static func matches(_ input: String, _ match: String, mode: Int, caseSensitive: Bool) -> Bool {
        let same = { caseSensitive ? input == match : input.caseInsensitiveCompare(match) == .orderedSame }
        switch mode {
        case 0: return same()
        case 1: return !same()
        case 2, 3:
            guard let a = Double(input.trimmingCharacters(in: .whitespaces)),
                  let b = Double(match.trimmingCharacters(in: .whitespaces)) else { return false }
            return mode == 2 ? a > b : a < b
        case 4:
            let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: match, options: options) else { return false }
            return regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil
        case 5: return isTrue(input)
        case 6: return !isTrue(input)
        default: return false
        }
    }

    /// "true", "yes" or a number other than 0.
    static func isTrue(_ text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespaces).lowercased()
        if let number = Double(text) { return number != 0 }
        return ["true", "yes"].contains(text)
    }
}

/// What a Grid View shows (S-053): its script's items, filtered by what is
/// typed when `filterable`; the chosen item's argument goes on along the
/// Grid View's lines.
public struct WorkflowGridRun: Equatable, Sendable {
    public var uid: String
    public var command: ScriptCommand
    public var variables: [String: String]
    public var filterable: Bool
    /// Shown while the script runs; empty for Reach's own.
    public var loading: String

    public init(uid: String, command: ScriptCommand, variables: [String: String] = [:], filterable: Bool = true, loading: String = "") {
        self.uid = uid
        self.command = command
        self.variables = variables
        self.filterable = filterable
        self.loading = loading
    }
}
