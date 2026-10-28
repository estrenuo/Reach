import Foundation

/// How well a query matches a result title. Higher is better; nil is no match.
/// Case and diacritics are ignored, so "cafe" finds "Café".
public enum Matcher {
    public static func score(query: String, title: String) -> Int? {
        let q = fold(query).filter { !$0.isWhitespace }
        guard !q.isEmpty else { return nil }
        let t = fold(title)
        let words = t.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if t == q { return 1000 }
        if t.hasPrefix(q) { return 900 - min(t.count - q.count, 99) }
        if words.contains(where: { $0.hasPrefix(q) }) { return 700 - min(t.count, 99) }
        let initials = String(words.compactMap(\.first))
        if initials.hasPrefix(q) { return 600 - min(initials.count - q.count, 99) }
        if wordStarts(q, words: words.map(String.init)) { return 500 - min(t.count, 99) }
        if t.contains(q) { return 300 - min(t.count, 99) }
        return nil
    }

    /// "vscode" matches "Visual Studio Code": the query is eaten by prefixes of
    /// consecutive words, each word giving at least one letter.
    private static func wordStarts(_ q: String, words: [String]) -> Bool {
        func eat(_ q: Substring, from index: Int) -> Bool {
            if q.isEmpty { return true }
            guard index < words.count else { return false }
            let word = words[index]
            var length = min(word.count, q.count)
            while length > 0 {
                if word.hasPrefix(q.prefix(length)), eat(q.dropFirst(length), from: index + 1) { return true }
                length -= 1
            }
            return eat(q, from: index + 1)
        }
        return eat(Substring(q), from: 0)
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
