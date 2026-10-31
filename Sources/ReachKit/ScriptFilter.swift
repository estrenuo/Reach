import Foundation

/// A Script Filter (S-041): a keyword whose script returns launcher rows as JSON.
public struct ScriptFilter: KeywordTrigger, Equatable {
    public static let type = "alfred.workflow.input.scriptfilter"
    public static let standardWaiting = "Please wait…"

    public typealias Argument = KeywordArgument
    public typealias Match = KeywordMatch

    public var uid: String
    public var keyword: String
    /// The keyword needs a space before the text, as in "gh reach".
    public var withSpace: Bool
    public var argument: Argument
    /// The row shown before the script answers: its title and subtext.
    public var title: String
    public var subtext: String
    /// The subtext while the script runs.
    public var waiting: String
    public var script: ScriptSource
    /// The launcher filters the script's rows itself; the script runs once with no text.
    public var filtersResults: Bool

    public init(uid: String, keyword: String, withSpace: Bool = true, argument: Argument = .required,
                title: String = "", subtext: String = "", waiting: String = "", script: ScriptSource,
                filtersResults: Bool = false) {
        self.uid = uid
        self.keyword = keyword
        self.withSpace = withSpace
        self.argument = argument
        self.title = title
        self.subtext = subtext
        self.waiting = waiting
        self.script = script
        self.filtersResults = filtersResults
    }

    /// Nil for another type of object, or one without a keyword.
    /// `variables` fill a keyword like `{var:keyword}`.
    public init?(_ object: WorkflowObject, variables: [String: String] = [:]) {
        guard object.type == Self.type, let keyword = Workflow.keyword(of: object, variables: variables) else { return nil }
        self.init(uid: object.uid, keyword: keyword, withSpace: object.config["withspace"]?.bool ?? true,
                  argument: Argument(rawValue: object.int("argumenttype")) ?? .required,
                  title: object.string("title"), subtext: object.string("subtext"),
                  waiting: object.string("runningsubtext"), script: ScriptSource(object),
                  filtersResults: object.bool("alfredfiltersresults"))
    }

    public var waitingText: String { waiting.isEmpty ? Self.standardWaiting : waiting }
}

/// The script of a Script Filter or Run Script object, in Alfred's settings.
public struct ScriptSource: Equatable, Sendable {
    /// Alfred's script types that Reach runs.
    public enum Language: Int, CaseIterable, Sendable {
        case bash = 0, ruby = 2, perl = 4, zsh = 5, appleScript = 6, javaScript = 7, file = 8, python3 = 9
        /// Alfred's default since 5.1.2: zsh without the user's startup files.
        case zshNoRCs = 11

        public var title: String {
            switch self {
            case .bash: "/bin/bash"
            case .ruby: "/usr/bin/ruby"
            case .perl: "/usr/bin/perl"
            case .zsh: "/bin/zsh"
            case .appleScript: "/usr/bin/osascript (AS)"
            case .javaScript: "/usr/bin/osascript (JS)"
            case .file: "External Script"
            case .python3: "/usr/bin/python3"
            case .zshNoRCs: "/bin/zsh --no-rcs"
            }
        }
    }

    /// Alfred's `type`; nil for a type Reach does not run, like PHP.
    public var language: Language?
    public var text: String
    /// For `.file`: the script's path inside the workflow folder.
    public var file: String
    /// True: the text goes to the script as its first argument. False: it
    /// replaces `{query}` in the script, escaped as `escaping` says.
    public var passesArgument: Bool
    public var escaping: Int

    public init(language: Language?, text: String = "", file: String = "", passesArgument: Bool = true, escaping: Int = 0) {
        self.language = language
        self.text = text
        self.file = file
        self.passesArgument = passesArgument
        self.escaping = escaping
    }

    public init(_ object: WorkflowObject) {
        self.init(language: Language(rawValue: object.int("type")), text: object.string("script"),
                  file: object.string("scriptfile"), passesArgument: object.int("scriptargtype", default: 1) == 1,
                  escaping: object.int("escaping"))
    }

    /// How to start the script with `query`, in the workflow folder; nil
    /// for a language Reach does not run.
    public func command(query: String, folder: URL, environment: [String: String] = [:]) -> ScriptCommand? {
        guard let language else { return nil }
        let body = passesArgument ? text : text.replacingOccurrences(of: "{query}", with: Self.escape(query, escaping))
        let args = passesArgument ? [query] : []
        let (executable, arguments): (String, [String]) = switch language {
        case .bash: ("/bin/bash", ["-c", body, "bash"] + args)
        case .zsh: ("/bin/zsh", ["-c", body, "zsh"] + args)
        case .zshNoRCs: ("/bin/zsh", ["--no-rcs", "-c", body, "zsh"] + args)
        case .ruby: ("/usr/bin/ruby", ["-e", body] + args)
        case .perl: ("/usr/bin/perl", ["-e", body] + args)
        case .python3: ("/usr/bin/python3", ["-c", body] + args)
        case .appleScript: ("/usr/bin/osascript", ["-e", body] + args)
        case .javaScript: ("/usr/bin/osascript", ["-l", "JavaScript", "-e", body] + args)
        case .file: (folder.appending(path: file).path, [query])
        }
        return ScriptCommand(executable: executable, arguments: arguments, directory: folder, environment: environment)
    }

    /// Alfred's escaping options for `{query}`, as bits.
    public static func escape(_ text: String, _ options: Int) -> String {
        var text = text
        let rules: [(Int, [Character])] = [
            (64, ["\\"]), (1, [" "]), (2, ["`"]), (4, ["\""]), (8, ["(", ")", "[", "]", "{", "}"]),
            (16, [";"]), (32, ["$"]), (128, ["'"]),
        ]
        for (bit, characters) in rules where options & bit != 0 {
            text = String(text.flatMap { characters.contains($0) ? ["\\", $0] : [$0] })
        }
        return text
    }
}

/// A process to start: what the app hands to `Process`.
public struct ScriptCommand: Equatable, Sendable {
    public var executable: String
    public var arguments: [String]
    public var directory: URL
    public var environment: [String: String]

    public init(executable: String, arguments: [String], directory: URL, environment: [String: String] = [:]) {
        self.executable = executable
        self.arguments = arguments
        self.directory = directory
        self.environment = environment
    }
}

/// What a Script Filter prints: Alfred's JSON format.
public struct ScriptFilterOutput: Decodable, Equatable, Sendable {
    public var items: [Item]
    public var variables: [String: String]
    /// Seconds after which the script runs again with the same text.
    public var rerun: Double?

    public struct Icon: Decodable, Equatable, Sendable {
        /// "fileicon" for the icon of the file at `path`, "filetype" for a type's icon, nil for an image file.
        public var type: String?
        public var path: String
    }

    public struct Text: Decodable, Equatable, Sendable {
        public var copy: String?
        public var largetype: String?
    }

    /// What a row does with a key held: ⌘ (cmd), ⌥ (alt), ⌃ (ctrl).
    public struct Mod: Decodable, Equatable, Sendable {
        public var valid: Bool
        public var arg: [String]?
        public var subtitle: String?
        public var variables: [String: String]

        enum CodingKeys: String, CodingKey { case valid, arg, subtitle, variables }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            valid = c.lenientBool(.valid) ?? true
            arg = c.lenientStrings(.arg)
            subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
            variables = c.lenientDictionary(.variables)
        }
    }

    public struct Item: Decodable, Equatable, Sendable {
        public var uid: String?
        public var title: String
        public var subtitle: String
        public var arg: [String]
        public var valid: Bool
        public var autocomplete: String?
        public var match: String?
        /// "file" for a path Reach can act on; "file:skipcheck" skips the check that it exists.
        public var type: String?
        public var icon: Icon?
        public var mods: [String: Mod]
        public var quicklookurl: String?
        public var text: Text?
        public var variables: [String: String]

        enum CodingKeys: String, CodingKey {
            case uid, title, subtitle, arg, valid, autocomplete, match, type, icon, mods, quicklookurl, text, variables
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            uid = c.lenientString(.uid)
            title = c.lenientString(.title) ?? ""
            subtitle = c.lenientString(.subtitle) ?? ""
            arg = c.lenientStrings(.arg) ?? []
            valid = c.lenientBool(.valid) ?? true
            autocomplete = c.lenientString(.autocomplete)
            match = c.lenientString(.match)
            type = c.lenientString(.type)
            icon = try? c.decodeIfPresent(Icon.self, forKey: .icon)
            mods = (try? c.decodeIfPresent([String: Mod].self, forKey: .mods)) ?? [:]
            quicklookurl = c.lenientString(.quicklookurl)
            text = try? c.decodeIfPresent(Text.self, forKey: .text)
            variables = c.lenientDictionary(.variables)
        }

        /// The first argument: what an Open URL or Copy action gets.
        public var argument: String { arg.first ?? "" }

        /// The row for a key held with Return, by the name the JSON uses.
        public func mod(_ name: String) -> Mod? { mods[name] }
    }

    enum CodingKeys: String, CodingKey { case items, variables, rerun }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decode([Item].self, forKey: .items)
        variables = c.lenientDictionary(.variables)
        rerun = try? c.decodeIfPresent(Double.self, forKey: .rerun)
    }

    public enum Failure: Error, Equatable, LocalizedError {
        case empty
        case notJSON(String)

        public var errorDescription: String? {
            switch self {
            case .empty: "The script printed nothing."
            case .notJSON(let start): "The script did not print Script Filter JSON: \(start)"
            }
        }
    }

    /// Reads a script's output. Text before the JSON (a stray `echo`) is skipped.
    public static func parse(_ data: Data) throws -> ScriptFilterOutput {
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw Failure.empty }
        let json = text.firstIndex(of: "{").map { String(text[$0...]) } ?? text
        do {
            return try JSONDecoder().decode(ScriptFilterOutput.self, from: Data(json.utf8))
        } catch {
            throw Failure.notJSON(String(text.prefix(80)))
        }
    }

    /// For a filter that leaves filtering to Reach: the rows whose `match`
    /// (else title) has a word that starts with each typed word.
    public func filtered(by text: String) -> [Item] {
        let words = text.lowercased().split(separator: " ")
        guard !words.isEmpty else { return items }
        return items.filter { item in
            let haystack = (item.match ?? item.title).lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            return words.allSatisfy { word in haystack.contains { $0.hasPrefix(word) } }
        }
    }
}

private extension KeyedDecodingContainer {
    /// A string, or a number or bool written where a string belongs.
    func lenientString(_ key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value ? "true" : "false" }
        return nil
    }

    func lenientStrings(_ key: Key) -> [String]? {
        if let values = try? decodeIfPresent([String].self, forKey: key) { return values }
        return lenientString(key).map { [$0] }
    }

    func lenientBool(_ key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return ["true", "yes", "1"].contains(value.lowercased()) }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value != 0 }
        return nil
    }

    func lenientDictionary(_ key: Key) -> [String: String] {
        guard let nested = try? nestedContainer(keyedBy: AnyKey.self, forKey: key) else { return [:] }
        var result: [String: String] = [:]
        for inner in nested.allKeys {
            if let value = nested.lenientString(inner) { result[inner.stringValue] = value }
        }
        return result
    }
}

private struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { stringValue = String(intValue); self.intValue = intValue }
}
