import Foundation

/// The last few characters typed in any app, to spot a snippet keyword
/// (S-031). Kept in memory only and emptied whenever the caret may have
/// moved: a click, an arrow key, another app.
public struct TypedBuffer: Sendable {
    /// Enough for any keyword plus the character before it.
    public static let limit = 64
    public private(set) var text = ""

    public init() {}

    public mutating func type(_ characters: String) {
        text += characters
        if text.count > Self.limit { text = String(text.suffix(Self.limit)) }
    }

    public mutating func backspace() {
        if !text.isEmpty { text.removeLast() }
    }

    public mutating func reset() { text = "" }

    /// The longest keyword the typed text ends with, at the start of a word:
    /// after a space, a line break or punctuation, or where the buffer began.
    /// Case counts, so "Sig" does not expand "sig".
    public func match(_ keywords: some Sequence<String>) -> String? {
        keywords
            .filter { !$0.isEmpty && text.hasSuffix($0) && Self.startsWord(text.dropLast($0.count)) }
            .max { $0.count < $1.count }
    }

    private static func startsWord(_ before: Substring) -> Bool {
        guard let last = before.last else { return true }
        return !(last.isLetter || last.isNumber)
    }
}
