import Foundation

/// Rules for snippet and collection names, and snippet keywords (S-029).
public enum SnippetName {
    /// Trims spaces and line breaks, collapses inner runs of spaces, and
    /// falls back to `fallback` for an empty name.
    public static func clean(_ text: String, fallback: String = "New Snippet") -> String {
        let words = text.split(whereSeparator: \.isWhitespace)
        return words.isEmpty ? fallback : words.joined(separator: " ")
    }

    /// A keyword is one word: spaces and line breaks are taken out.
    public static func keyword(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }

    /// Another keyword that `keyword` starts with (S-031): while typing, that
    /// one expands first, so `keyword` never does. Nil when none.
    public static func shadow(of keyword: String, in others: some Sequence<String>) -> String? {
        others.filter { !$0.isEmpty && $0.count < keyword.count && keyword.hasPrefix($0) }.max { $0.count < $1.count }
    }
}

/// Finding a snippet by what is typed (S-029, used by `snip` in S-030).
public enum SnippetSearch {
    /// How well `query` finds a snippet; nil is no match. A keyword typed in
    /// full beats everything, then the better of the keyword and the name.
    public static func score(_ query: String, name: String, keyword: String) -> Int? {
        let typed = query.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return nil }
        if !keyword.isEmpty, Matcher.fold(keyword) == Matcher.fold(typed) { return 1100 }
        let byKeyword = keyword.isEmpty ? nil : Matcher.score(query: typed, title: keyword)
        return [Matcher.score(query: typed, title: name), byKeyword].compactMap { $0 }.max()
    }
}
