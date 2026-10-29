import Foundation

/// Filling in a snippet's placeholders when it is pasted (S-030).
public enum SnippetText {
    public static let placeholders = ["{date}", "{time}", "{clipboard}"]

    /// Replaces `{date}`, `{time}` and `{clipboard}` in one pass, so text that
    /// comes from the clipboard is never filled in again. Other braces stay.
    /// Without text on the clipboard, `{clipboard}` becomes nothing.
    public static func expand(_ text: String, date: Date, clipboard: String?,
                              locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        guard text.contains("{") else { return text }
        let day = date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: timeZone))
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone))
        return text.replacing(/\{(date|time|clipboard)\}/) { match in
            switch match.output.1 {
            case "date": day
            case "time": time
            default: clipboard ?? ""
            }
        }
    }

    /// The first line, for the row under the snippet's name.
    public static func preview(_ text: String, limit: Int = 120) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count > limit ? String(trimmed.prefix(limit)) + "…" : trimmed
    }
}
