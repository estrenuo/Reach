import Foundation

/// Rules for snippet names. Logic lives in this library so tests can run it
/// without the app. Put parsers, date rules, and data rules here too.
public enum SnippetName {
    /// Trims spaces and line breaks, collapses inner runs of spaces, and
    /// falls back to "New Snippet" for an empty name.
    public static func clean(_ text: String) -> String {
        let words = text.split(whereSeparator: \.isWhitespace)
        return words.isEmpty ? "New Snippet" : words.joined(separator: " ")
    }
}
