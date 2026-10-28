import Foundation

/// What the query asks for, read from its keyword.
public enum QueryKind: Equatable, Sendable {
    case empty
    /// Apps and everything else ranked together.
    case normal(String)
    /// File search: `open <name>`, `'<name>` or ` <name>`. The name may be empty.
    case files(String)

    public static let fileKeywords = ["open "]
    public static let filePrefixes: [Character] = ["'", " "]

    public init(_ query: String) {
        if query.isEmpty { self = .empty; return }
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
