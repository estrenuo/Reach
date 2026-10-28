import Foundation

/// Something the action panel can do with selected text. Web searches come
/// from the fallback engines and are not listed here.
public enum TextAction: String, CaseIterable, Sendable {
    case largeType, copyPlainText

    public var title: String {
        switch self {
        case .largeType: "Show in Large Type"
        case .copyPlainText: "Copy as Plain Text"
        }
    }

    public var summary: String {
        switch self {
        case .largeType: "Show the text in huge letters over the screen"
        case .copyPlainText: "Copy the text without its fonts and colors"
        }
    }

    public var symbol: String {
        switch self {
        case .largeType: "textformat.size"
        case .copyPlainText: "doc.plaintext"
        }
    }

    /// Actions whose title matches `filter`; all of them for an empty filter.
    public static func filtered(by filter: String) -> [TextAction] {
        let text = filter.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return allCases }
        return allCases.filter { Matcher.score(query: text, title: $0.title) != nil }
    }

    /// The header line for selected text: its first line, cut at `limit` characters.
    public static func headline(_ text: String, limit: Int = 60) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count > limit ? String(trimmed.prefix(limit - 1)) + "…" : trimmed
    }
}

extension KeyCombo {
    /// The selection hotkey: ⌃⌥⌘\ while Alfred still owns ⌥⌘\.
    public static let selection = KeyCombo(keyCode: 42, modifiers: control | option | command)
}
