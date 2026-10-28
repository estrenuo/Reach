import Foundation

/// What the query asks for, read from its keyword.
public enum QueryKind: Equatable, Sendable {
    case empty
    /// Apps and everything else ranked together.
    case normal(String)
    /// File search: `open <name>`, `'<name>` or ` <name>`. The name may be empty.
    case files(String)
    /// Browsing: a query that starts with `~/` or `/`.
    case path(PathQuery)

    /// The words after any keyword: what fallbacks search the web for.
    /// Empty while browsing, so a path never offers web searches.
    public var text: String {
        switch self {
        case .empty, .path: ""
        case .normal(let text), .files(let text): text
        }
    }

    public static let fileKeywords = ["open "]
    public static let filePrefixes: [Character] = ["'", " "]

    public init(_ query: String) {
        if query.isEmpty { self = .empty; return }
        if let path = PathQuery(query) { self = .path(path); return }
        for keyword in Self.fileKeywords where query.lowercased().hasPrefix(keyword) {
            self = .files(Self.trimmed(query.dropFirst(keyword.count)))
            return
        }
        if let first = query.first, Self.filePrefixes.contains(first) {
            self = .files(Self.trimmed(query.dropFirst()))
            return
        }
        let text = Self.trimmed(Substring(query))
        self = text.isEmpty ? .empty : .normal(text)
    }

    private static func trimmed(_ text: Substring) -> String {
        text.trimmingCharacters(in: .whitespaces)
    }
}
