import CoreServices
import Foundation

/// `define <word>` and `spell <word>` (S-022). Definitions come from the
/// macOS dictionary service, the dictionaries ticked in Dictionary.app.
public enum DictionaryLookup {
    public enum Mode: String, CaseIterable, Codable, Sendable {
        case define, spell

        public var title: String {
            switch self {
            case .define: "Define a Word"
            case .spell: "Spell a Word"
            }
        }
    }

    /// The longest subtitle; longer definitions end in an ellipsis.
    public static let summaryLength = 120

    /// The whole text definition of `word`, or nil when no dictionary has it.
    public static func definition(of word: String) -> String? {
        let text = word.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        let range = CFRange(location: 0, length: (text as NSString).length)
        return DCSCopyTextDefinition(nil, text as CFString, range)?.takeRetainedValue() as String?
    }

    /// The first sense of a definition, for a row's subtitle. Drops the
    /// headword, the pronunciation between bars, the sense number, and
    /// everything from the first example (▸) or the second sense on.
    public static func summary(of definition: String, word: String) -> String {
        var text = Substring(definition.trimmingCharacters(in: .whitespacesAndNewlines))
        if text.lowercased().hasPrefix(word.lowercased()) { text = text.dropFirst(word.count) }
        text = text.drop(while: \.isWhitespace)
        if text.hasPrefix("|"), let end = text.dropFirst().firstIndex(of: "|") {
            text = text[text.index(after: end)...]
        }
        var summary = String(text)
        if let example = summary.range(of: "▸") { summary = String(summary[..<example.lowerBound]) }
        if let second = summary.range(of: #"\s2\s"#, options: .regularExpression) {
            summary = String(summary[..<second.lowerBound])
        }
        summary = summary.replacingOccurrences(of: #"(^|\s)1\s"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        guard summary.count > summaryLength else { return summary }
        return summary.prefix(summaryLength - 1).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// `define seren` with keyword `define` gives "seren". Empty for the
    /// keyword and a space; nil when the query does not start that way.
    public static func word(in query: String, keyword: String) -> String? {
        let word = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        guard !word.isEmpty, query.lowercased().hasPrefix(word + " ") else { return nil }
        return query.dropFirst(word.count + 1).trimmingCharacters(in: .whitespaces)
    }

    /// Why `keyword` will not do, or nil when it will. `taken` maps the other
    /// keywords in use (file search, system commands) to what they do.
    public static func problem(keyword: String, other: String, taken: [String: String] = [:]) -> String? {
        let word = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        if word.isEmpty { return "Type a keyword." }
        if word.contains(where: \.isWhitespace) { return "A keyword is one word, without spaces." }
        if word == other.lowercased() { return "“\(keyword)” is already the keyword for the other lookup." }
        if let owner = taken[word] { return "“\(keyword)” is already the keyword for \(owner)." }
        return nil
    }
}
