import Foundation

/// An object a typed keyword starts: a Script Filter or a Keyword input.
/// The keyword rules are the same for both.
public protocol KeywordTrigger: Sendable {
    var uid: String { get }
    var keyword: String { get }
    /// The keyword needs a space before the text, as in "gh reach".
    var withSpace: Bool { get }
    var argument: KeywordArgument { get }
    /// The row's title before anything runs, and its subtext.
    var title: String { get }
    var subtext: String { get }
}

/// Whether text after the keyword is needed: Alfred's `argumenttype`.
public enum KeywordArgument: Int, Sendable {
    case required = 0, optional = 1, none = 2
}

/// What the typed query means for a keyword.
public enum KeywordMatch: Equatable, Sendable {
    /// Part of the keyword is typed: a row that completes it.
    case keyword
    /// The keyword is typed and the text is still missing.
    case needsText
    /// Run with this text.
    case run(String)
}

extension KeywordTrigger {
    /// The row title: the title, else the keyword.
    public var placeholder: String { title.isEmpty ? keyword : title }

    public func match(_ query: String) -> KeywordMatch? {
        guard !query.isEmpty else { return nil }
        let typed = query.lowercased()
        let word = keyword.lowercased()
        guard typed.hasPrefix(word) else {
            return word.hasPrefix(typed) && !typed.contains(" ") ? .keyword : nil
        }
        var rest = Substring(query.dropFirst(keyword.count))
        if rest.isEmpty {
            return argument == .required ? .needsText : .run("")
        }
        if withSpace || rest.first == " " {
            guard rest.first == " " else { return nil }
            rest = rest.dropFirst()
        }
        if argument == .none { return rest.allSatisfy(\.isWhitespace) ? .run("") : nil }
        if rest.isEmpty, argument == .required { return .needsText }
        return .run(String(rest))
    }

    /// What Return types for a row of the `.keyword` or `.needsText` kind.
    public var completion: String { keyword + (withSpace ? " " : "") }
}

/// A Keyword input: the keyword sends the text after it straight on to the
/// objects connected to it, such as Run Script or Open URL. Alfred's
/// `alfred.workflow.input.keyword`.
public struct KeywordInput: KeywordTrigger, Equatable {
    public static let type = "alfred.workflow.input.keyword"

    public var uid: String
    public var keyword: String
    public var withSpace: Bool
    public var argument: KeywordArgument
    public var title: String
    public var subtext: String

    public init(uid: String, keyword: String, withSpace: Bool = true, argument: KeywordArgument = .required,
                title: String = "", subtext: String = "") {
        self.uid = uid
        self.keyword = keyword
        self.withSpace = withSpace
        self.argument = argument
        self.title = title
        self.subtext = subtext
    }

    /// Nil for another type of object, or one without a keyword.
    /// `variables` fill a keyword like `{var:keyword}`.
    public init?(_ object: WorkflowObject, variables: [String: String] = [:]) {
        guard object.type == Self.type,
              let keyword = Workflow.keyword(of: object, variables: variables) else { return nil }
        self.init(uid: object.uid, keyword: keyword, withSpace: object.config["withspace"]?.bool ?? true,
                  argument: KeywordArgument(rawValue: object.int("argumenttype")) ?? .required,
                  title: object.string("text"), subtext: object.string("subtext"))
    }

    /// The title once the text is typed: `{query}` in it becomes the text.
    public func title(for text: String) -> String {
        WorkflowText.fill(placeholder, query: text)
    }
}

extension Workflow {
    /// The values `{var:name}` fills in a keyword: the workflow's variables
    /// and its configuration, which wins.
    public var keywordVariables: [String: String] {
        variables.merging(WorkflowConfiguration.resolved(settings, saved: configuration)) { _, new in new }
    }

    /// An object's keyword with `{var:…}` filled in; nil when it is empty
    /// or names a variable that has no value.
    static func keyword(of object: WorkflowObject, variables: [String: String]) -> String? {
        let keyword = WorkflowText.fill(object.string("keyword"), query: "{query}", variables: variables)
            .trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty, !keyword.contains("{var:") else { return nil }
        return keyword
    }

    /// The Keyword inputs, each with a keyword.
    public var keywordInputs: [KeywordInput] {
        let values = keywordVariables
        return objects.compactMap { KeywordInput($0, variables: values) }
    }

    /// Every keyword the launcher answers, from script filters, keyword inputs and file filters.
    public var keywords: [String] { scriptFilters.map(\.keyword) + keywordInputs.map(\.keyword) + fileFilters.map(\.keyword) }
}
