import Foundation

/// What Return on a workflow row does (S-041): the objects connected to the
/// script filter, turned into steps the app runs. Reach runs a few kinds of
/// object; the rest are skipped.
public enum WorkflowStep: Equatable, Sendable {
    /// Open a URL, or a file when the text is a path.
    case open(String)
    case reveal(String)
    case copy(String)
    case largeType(String)
    /// Run a script; its output goes on to the objects after `then`.
    case run(ScriptCommand, then: String)
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

    /// The steps for the objects connected to `uid` with `modifiers` held.
    /// With nothing connected, a URL or a path is opened.
    public func steps(after uid: String, argument: String, modifiers: Int = 0,
                      variables: [String: String] = [:], environment: [String: String] = [:]) -> [WorkflowStep] {
        let all = connections[uid] ?? []
        if all.isEmpty, object(uid)?.type == ScriptFilter.type {
            return Self.opensItself(argument) ? [.open(argument)] : []
        }
        let lines = all.filter { $0.modifiers == modifiers }
        return lines.flatMap { line -> [WorkflowStep] in
            guard let object = object(line.to) else { return [] }
            let fill = { (text: String) in WorkflowText.fill(text, query: argument, variables: variables) }
            switch object.type {
            case Self.openURL:
                let template = object.string("url")
                return [.open(template.isEmpty ? argument : WorkflowText.fill(template, query: argument, variables: variables,
                                                                             encodeQuery: template != "{query}"))]
            case Self.openFile:
                let file = object.string("sourcefile")
                return [.open(file.isEmpty ? argument : fill(file))]
            case Self.revealFile:
                return [.reveal(argument)]
            case Self.copyToClipboard:
                let text = object.string("clipboardtext")
                return [.copy(text.isEmpty ? argument : fill(text))]
            case Self.largeType:
                let text = object.string("largetypetext")
                return [.largeType(text.isEmpty ? argument : fill(text))]
            case Self.runScript:
                guard let command = ScriptSource(object).command(query: argument, folder: folder, environment: environment)
                else { return [] }
                return [.run(command, then: object.uid)]
            case Self.junction:
                return steps(after: object.uid, argument: argument, variables: variables, environment: environment)
            case Self.argument:
                let text = object.string("argument")
                return steps(after: object.uid, argument: text.isEmpty ? argument : fill(text),
                             variables: variables, environment: environment)
            default:
                return []
            }
        }
    }

    static func opensItself(_ text: String) -> Bool {
        text.hasPrefix("/") || text.hasPrefix("~/") || (URL(string: text)?.scheme.map { !$0.isEmpty } ?? false)
    }
}

/// Fills `{query}` and `{var:name}` in an object's text.
public enum WorkflowText {
    public static func fill(_ text: String, query: String, variables: [String: String] = [:], encodeQuery: Bool = false) -> String {
        let value = encodeQuery ? (query.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? query) : query
        var result = text.replacingOccurrences(of: "{query}", with: value)
        for (name, variable) in variables {
            result = result.replacingOccurrences(of: "{var:\(name)}", with: variable)
        }
        return result
    }
}
