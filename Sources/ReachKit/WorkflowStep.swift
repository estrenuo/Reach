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
        return follow(all.filter { $0.modifiers == modifiers }, argument: argument, variables: variables,
                      environment: environment, depth: 0)
    }

    /// The steps after `uid` without a modifier, on the lines that leave `output`.
    /// `config` overrides the next objects' configuration (JSON Config, S-052).
    private func next(after uid: String, output: String? = nil, argument: String, variables: [String: String],
                      environment: [String: String], config: [String: PlistValue] = [:], depth: Int) -> [WorkflowStep] {
        let lines = (connections[uid] ?? []).filter { $0.modifiers == 0 && $0.sourceOutput == output }
        return follow(lines, argument: argument, variables: variables, environment: environment, config: config, depth: depth + 1)
    }

    private func follow(_ lines: [WorkflowConnection], argument: String, variables: [String: String],
                        environment: [String: String], config: [String: PlistValue] = [:], depth: Int) -> [WorkflowStep] {
        guard depth < Self.deepest else { return [] }
        return lines.flatMap { line -> [WorkflowStep] in
            guard var object = object(line.to) else { return [] }
            object.config.merge(config) { _, new in new }
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
                else { return [.unsupported("a script in this language")] }
                return [.run(command, then: object.uid, variables: variables)]
            case Self.junction:
                return next(after: object.uid, argument: argument, variables: variables, environment: environment, depth: depth)
            case Self.argument:
                let text = object.string("argument")
                let set = (object.config["variables"]?.dict ?? [:]).compactMapValues(\.string).mapValues(fill)
                return next(after: object.uid, argument: text.isEmpty ? argument : fill(text),
                            variables: variables.merging(set) { _, new in new },
                            environment: environment.merging(set) { _, new in new }, depth: depth)
            case Self.conditional:
                let output = WorkflowCondition.output(of: object, query: argument, variables: variables)
                return next(after: object.uid, output: output, argument: argument, variables: variables,
                            environment: environment, depth: depth)
            case Self.split:
                let parts = WorkflowSplit.parts(of: argument, object)
                // As variables the argument goes on as it is; as arguments
                // Reach runs the objects after it once for each part.
                guard object.int("outputas") == 1 else {
                    let set = WorkflowSplit.variables(parts, object)
                    return next(after: object.uid, argument: argument, variables: variables.merging(set) { _, new in new },
                                environment: environment.merging(set) { _, new in new }, depth: depth)
                }
                return parts.flatMap { next(after: object.uid, argument: $0, variables: variables, environment: environment, depth: depth) }
            case Self.replace:
                switch WorkflowReplace.apply(to: argument, object) {
                case .success(let text):
                    return next(after: object.uid, argument: text, variables: variables, environment: environment, depth: depth)
                case .failure(let problem):
                    return [.unsupported(problem.kind)]
                }
            case Self.json:
                guard let output = WorkflowJSON.read(object, query: argument, variables: variables) else {
                    return [.unsupported("utility.json with JSON that does not parse")]
                }
                return next(after: object.uid, argument: output.argument ?? argument,
                            variables: variables.merging(output.variables) { _, new in new },
                            environment: environment.merging(output.variables) { _, new in new }, config: output.config, depth: depth)
            case Self.hideAlfred:
                // Reach hides the launcher after Return anyway.
                return []
            case Self.callExternalTrigger:
                let bundle = object.string("workflowbundleid")
                guard ["", "self", bundleID].contains(bundle) else { return [.unsupported("an External Trigger in another workflow")] }
                let id = object.string("externaltriggerid")
                guard let trigger = objects.first(where: { $0.type == Self.externalTrigger && $0.string("triggerid") == id })
                else { return [] }
                let passes = object.bool("passvariables")
                // Without passvariables the trigger starts from the workflow's own variables.
                let own = environment.filter { key, _ in variables[key] == nil || self.variables[key] != nil }
                return next(after: trigger.uid, argument: object.bool("passinputasargument") ? argument : "",
                            variables: passes ? variables : self.variables, environment: passes ? environment : own,
                            depth: depth)
            case Self.automationTask where object.string("taskuid") == Self.trashTask:
                let target = object.config["tasksettings"]?.dict?["target_path"]?.string ?? ""
                let path = target.isEmpty ? argument : fill(target)
                // The objects after it run once the file is in the Trash, with its path.
                return [.trash(path)] + next(after: object.uid, argument: path, variables: variables,
                                             environment: environment, depth: depth)
            case Self.notification:
                // Like Alfred, the argument goes on to the objects after it.
                let after = next(after: object.uid, argument: argument, variables: variables,
                                 environment: environment, depth: depth)
                if object.bool("onlyshowifquerypopulated") && argument.isEmpty { return after }
                var shown = argument
                if object.bool("lastpathcomponent") { shown = (shown as NSString).lastPathComponent }
                if object.bool("removeextension") { shown = (shown as NSString).deletingPathExtension }
                let title = WorkflowText.fill(object.string("title"), query: shown, variables: variables)
                return [.notify(title: title.isEmpty ? name : title,
                                text: WorkflowText.fill(object.string("text"), query: shown, variables: variables))] + after
            case Self.playSound:
                let name = object.string("soundname")
                let after = next(after: object.uid, argument: argument, variables: variables,
                                 environment: environment, depth: depth)
                guard !name.isEmpty else { return after }
                // A sound that is not a system sound is a file in the workflow's folder.
                return [.sound(object.bool("systemsound") ? name : folder.appending(path: name).path)] + after
            case Self.debug:
                let template = object.string("argument")
                let line = WorkflowText.fill(template.isEmpty ? "{query}" : template, query: argument, variables: variables)
                    .replacingOccurrences(of: "{variables}", with: Self.describe(variables))
                // Without "process outputs" the objects after it do not run.
                let after = object.config["processoutputs"]?.bool ?? true
                    ? next(after: object.uid, argument: argument, variables: variables, environment: environment, depth: depth)
                    : []
                return [.debug(line, clear: object.bool("cleardebuggertext"))] + after
            case ScriptFilter.type, KeywordInput.type:
                guard let keyword = scriptFilters.first(where: { $0.uid == object.uid })?.keyword
                    ?? keywordInputs.first(where: { $0.uid == object.uid })?.keyword else { return [] }
                return [.show(keyword + " " + argument)]
            default:
                return [.unsupported(object.type.replacingOccurrences(of: "alfred.workflow.", with: ""))]
            }
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
