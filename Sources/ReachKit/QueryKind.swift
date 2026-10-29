import Foundation

/// What the query asks for, read from its keyword.
public enum QueryKind: Equatable, Sendable {
    case empty
    /// Apps and everything else ranked together.
    case normal(String)
    /// File search: `open <name>`, `'<name>`, ` <name>`, or another file keyword (S-014). The text may be empty.
    case files(FileQuery)
    /// Browsing: a query that starts with `~/` or `/`.
    case path(PathQuery)
    /// A shell command after the Terminal prefix (S-021): `> ls -la`. May be empty.
    case shell(String)

    /// The words after any keyword: what fallbacks search the web for.
    /// Empty while browsing or for a shell command, so neither offers web searches.
    public var text: String {
        switch self {
        case .empty, .path, .shell: ""
        case .normal(let text): text
        case .files(let query): query.text
        }
    }

    /// Quick file search: these open files whatever the keywords are.
    public static let filePrefixes: [Character] = ["'", " "]

    /// A keyword that is off makes its query a normal search.
    public init(_ query: String, keywords: FileKeywords = FileKeywords(), shellPrefix: String? = nil) {
        if query.isEmpty { self = .empty; return }
        if let shellPrefix, let command = ShellCommand.command(in: query, prefix: shellPrefix) {
            self = .shell(command)
            return
        }
        if let path = PathQuery(query) { self = .path(path); return }
        if let (mode, rest) = keywords.match(query) {
            self = .files(FileQuery(mode, Self.trimmed(rest)))
            return
        }
        if let first = query.first, Self.filePrefixes.contains(first) {
            self = .files(FileQuery(.open, Self.trimmed(query.dropFirst())))
            return
        }
        let text = Self.trimmed(Substring(query))
        self = text.isEmpty ? .empty : .normal(text)
    }

    private static func trimmed(_ text: Substring) -> String {
        text.trimmingCharacters(in: .whitespaces)
    }
}
