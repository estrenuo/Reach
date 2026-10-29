import AppKit
import ReachKit

/// Settings > Dictionary (S-022): the spelling language and the two
/// keywords, each on or off. Saved in `Store.settings`.
@Observable
final class DictionarySettings {
    static let shared = DictionarySettings()
    private static let languageKey = "dictionary.language"
    private static let keywordKey = "dictionary.keyword."
    private static let onKey = "dictionary.on."

    /// A spell checker language like "en_GB"; empty follows macOS.
    var language: String {
        didSet { Store.settings.set(language, forKey: Self.languageKey) }
    }
    var keywords: [DictionaryLookup.Mode: String] {
        didSet { for (mode, word) in keywords { Store.settings.set(word, forKey: Self.keywordKey + mode.rawValue) } }
    }
    var isOn: [DictionaryLookup.Mode: Bool] {
        didSet { for (mode, on) in isOn { Store.settings.set(on, forKey: Self.onKey + mode.rawValue) } }
    }

    private init() {
        let defaults = Store.settings
        language = defaults.string(forKey: Self.languageKey) ?? ""
        keywords = Dictionary(uniqueKeysWithValues: DictionaryLookup.Mode.allCases.map {
            ($0, defaults.string(forKey: Self.keywordKey + $0.rawValue) ?? $0.rawValue)
        })
        isOn = Dictionary(uniqueKeysWithValues: DictionaryLookup.Mode.allCases.map {
            ($0, defaults.object(forKey: Self.onKey + $0.rawValue) as? Bool ?? true)
        })
    }

    func keyword(_ mode: DictionaryLookup.Mode) -> String { keywords[mode] ?? mode.rawValue }

    /// The spell checker's languages, by name, after Automatic.
    static var languages: [(id: String, name: String)] {
        let all = NSSpellChecker.shared.availableLanguages.map { ($0, Locale.current.localizedString(forIdentifier: $0) ?? $0) }
        return [("", "Automatic")] + all.sorted { $0.1.localizedStandardCompare($1.1) == .orderedAscending }
    }

    /// Back to `define`, `spell` and Automatic; the self-test leaves no trace this way.
    func reset() {
        language = ""
        keywords = [.define: "define", .spell: "spell"]
        isOn = [.define: true, .spell: true]
    }
}

/// `define <word>`: words with a definition, the first sense as the
/// subtitle; Return opens Dictionary.app. `spell <word>`: spellings;
/// Return copies one, Command-Return pastes it (S-022).
final class DictionarySource: ResultSource {
    static let app = "/System/Applications/Dictionary.app"
    static let icon = LaunchResult.Icon.file(app)
    static let spellHelp = "↩ copies it, ⌘↩ pastes it"
    let settings: DictionarySettings
    /// The macOS dictionary service. The self-test swaps in a fake.
    var define: (String) -> String? = { DictionaryLookup.definition(of: $0) }
    /// Words that start with these letters, in a language (nil: automatic). The self-test swaps in a fake.
    var completions: (String, String?) -> [String] = { DictionarySource.spellChecker(completing: $0, language: $1) }
    /// The word itself when it is spelled right, else the checker's guesses. The self-test swaps in a fake.
    var guesses: (String, String?) -> [String] = { DictionarySource.spellChecker(guessing: $0, language: $1) }

    init(settings: DictionarySettings = .shared) {
        self.settings = settings
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query else { return [] }
        return DictionaryLookup.Mode.allCases.flatMap { mode -> [Scored] in
            guard settings.isOn[mode] != false else { return [] }
            let keyword = settings.keyword(mode)
            // The query comes trimmed, so `define ` arrives as the keyword alone.
            let word = text.lowercased() == keyword.lowercased() ? "" : DictionaryLookup.word(in: text, keyword: keyword)
            guard let word else { return offer(mode, keyword: keyword, text: text) }
            guard !word.isEmpty else { return [hint(mode, mode == .define ? "Type a word to define" : "Type a word to spell")] }
            let rows = mode == .define ? definitions(word) : spellings(word)
            guard !rows.isEmpty else {
                return [hint(mode, mode == .define ? "No definition for “\(word)”" : "No spellings for “\(word)”")]
            }
            return rows.map { Scored(result: $0, score: 0) }
        }
    }

    /// Part of the keyword (`defi`) or all of it: a row that completes to `define `.
    private func offer(_ mode: DictionaryLookup.Mode, keyword: String, text: String) -> [Scored] {
        guard text.count >= 2, text.count < keyword.count, keyword.lowercased().hasPrefix(text.lowercased()),
              let score = Matcher.score(query: text, title: keyword), score >= SystemCommands.minimumScore else { return [] }
        return [Scored(result: LaunchResult(id: "dictionary:\(mode.rawValue)", title: "\(mode.title)…",
                                            subtitle: "Press ↩ to type a word", icon: Self.icon, url: nil,
                                            kindLabel: "Dictionary", completes: keyword + " "), score: score)]
    }

    private func definitions(_ word: String) -> [LaunchResult] {
        var seen = Set<String>()
        let words = ([word] + completions(word, language)).filter { seen.insert($0.lowercased()).inserted }
        return words.lazy.compactMap { candidate -> LaunchResult? in
            guard let definition = self.define(candidate) else { return nil }
            return LaunchResult(id: "define:\(candidate)", title: candidate,
                                subtitle: DictionaryLookup.summary(of: definition, word: candidate),
                                icon: Self.icon, url: Self.dictionaryURL(candidate), kindLabel: "Definition", isPinned: true)
        }.prefix(LauncherModel.maxResults).map { $0 }
    }

    private func spellings(_ word: String) -> [LaunchResult] {
        var seen = Set<String>()
        let words = (guesses(word, language) + completions(word, language)).filter { seen.insert($0.lowercased()).inserted }
        return words.prefix(LauncherModel.maxResults).map {
            LaunchResult(id: "spell:\($0)", title: $0, subtitle: Self.spellHelp, icon: Self.icon, url: nil,
                         kindLabel: "Spelling", answer: $0, isPinned: true)
        }
    }

    private func hint(_ mode: DictionaryLookup.Mode, _ title: String) -> Scored {
        Scored(result: LaunchResult(id: "hint:\(mode.rawValue)", title: title, subtitle: "", icon: Self.icon, url: nil), score: 0)
    }

    private var language: String? { settings.language.isEmpty ? nil : settings.language }

    static func dictionaryURL(_ word: String) -> URL? {
        word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed).flatMap { URL(string: "dict://\($0)") }
    }

    static func spellChecker(completing word: String, language: String?) -> [String] {
        NSSpellChecker.shared.completions(forPartialWordRange: NSRange(location: 0, length: (word as NSString).length),
                                          in: word, language: language, inSpellDocumentWithTag: 0) ?? []
    }

    static func spellChecker(guessing word: String, language: String?) -> [String] {
        let checker = NSSpellChecker.shared
        let range = NSRange(location: 0, length: (word as NSString).length)
        let wrong = checker.checkSpelling(of: word, startingAt: 0, language: language, wrap: false,
                                          inSpellDocumentWithTag: 0, wordCount: nil)
        guard wrong.location != NSNotFound else { return [word] }
        return checker.guesses(forWordRange: range, in: word, language: language, inSpellDocumentWithTag: 0) ?? []
    }
}
