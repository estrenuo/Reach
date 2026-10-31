import Foundation

/// What a file search keyword does (S-014): open, reveal, search contents, search tags.
public enum FileMode: String, CaseIterable, Codable, Sendable {
    case open, reveal, inside, tags

    /// The keyword it has until people change it in Settings > Search.
    public var standardWord: String {
        switch self {
        case .open: "open"
        case .reveal: "find"
        case .inside: "in"
        case .tags: "tags"
        }
    }

    /// The label in Settings > Search.
    public var title: String {
        switch self {
        case .open: "Open files"
        case .reveal: "Reveal in Finder"
        case .inside: "Search inside files"
        case .tags: "Search file tags"
        }
    }
}

/// The file search keywords: a word per mode, and whether it is on.
public struct FileKeywords: Equatable, Codable, Sendable {
    public struct Keyword: Equatable, Codable, Sendable {
        public var word: String
        public var isOn: Bool
    }

    private var keywords: [FileMode: Keyword]

    public init() {
        keywords = Dictionary(uniqueKeysWithValues: FileMode.allCases.map { ($0, Keyword(word: $0.standardWord, isOn: true)) })
    }

    public subscript(mode: FileMode) -> Keyword {
        get { keywords[mode] ?? Keyword(word: mode.standardWord, isOn: true) }
        set { keywords[mode] = newValue }
    }

    /// The mode whose keyword starts `query`, with the text after it. A keyword
    /// counts only when a space follows it, so "inbox" is not "in box".
    func match(_ query: String) -> (FileMode, Substring)? {
        let lowered = query.lowercased()
        for mode in FileMode.allCases {
            let keyword = self[mode]
            guard keyword.isOn, lowered.hasPrefix(keyword.word + " ") else { continue }
            return (mode, query.dropFirst(keyword.word.count + 1))
        }
        return nil
    }

    /// Why `word` cannot be the keyword for `mode`, or nil when it can.
    public func problem(with word: String, for mode: FileMode) -> String? {
        if word.isEmpty { return "Type a keyword." }
        if word.contains(where: \.isWhitespace) { return "A keyword is one word, without spaces." }
        if let first = word.first, "~/'".contains(first) { return "A keyword can’t start with ~, / or '." }
        if let other = FileMode.allCases.first(where: { $0 != mode && self[$0].word == word }) {
            return "“\(word)” is already the keyword for \(other.title)."
        }
        return nil
    }
}

/// A file search: the mode from the keyword and the words after it.
public struct FileQuery: Equatable, Sendable {
    public var mode: FileMode
    public var text: String

    public init(_ mode: FileMode, _ text: String) {
        self.mode = mode
        self.text = text
    }

    /// ↩ on a result reveals it in Finder instead of opening it.
    public var reveals: Bool { mode == .reveal }
}

/// File kinds the keywords can leave out, under Don't Show in Settings > Search.
public enum HiddenKind: String, CaseIterable, Codable, Sendable {
    case emails, contacts, bookmarks, history, music, images, sourceFiles, compiled, calendar, plists, messages

    /// On until people change it, as in Alfred, plus compiled code like .pyc caches.
    public static let standard: Set<HiddenKind> = [.contacts, .bookmarks, .history, .compiled, .calendar, .plists, .messages]

    public var title: String {
        switch self {
        case .emails: "Mail messages"
        case .contacts: "Contacts"
        case .bookmarks: "Bookmarks"
        case .history: "History"
        case .music: "Music"
        case .images: "Images"
        case .sourceFiles: "Source code"
        case .compiled: "Compiled code"
        case .calendar: "Calendar events"
        case .plists: "Property lists"
        case .messages: "Messages"
        }
    }

    /// The content types Spotlight files them under.
    public var contentTypes: [String] {
        switch self {
        case .emails: ["com.apple.mail.emlx", "public.email-message"]
        case .contacts: ["com.apple.addressbook.person", "public.vcard"]
        case .bookmarks: ["com.apple.safari.bookmark", "com.apple.web-internet-location"]
        case .history: ["com.apple.safari.history"]
        case .music: ["public.audio"]
        case .images: ["public.image"]
        case .sourceFiles: ["public.source-code"]
        case .compiled: ["public.python-bytecode", "public.object-code", "com.sun.java-class"]
        case .calendar: ["com.apple.ical.bookmark", "com.apple.ical.ics"]
        case .plists: ["com.apple.property-list"]
        case .messages: ["com.apple.ichat.transcript"]
        }
    }
}

/// File types a query without a keyword also shows, under Default Results.
/// All off at first, so the default results stay fast and about apps.
public enum ResultType: String, CaseIterable, Codable, Sendable {
    case folders, documents, textFiles, images, archives, appleScripts

    public var title: String {
        switch self {
        case .folders: "Folders"
        case .documents: "Documents"
        case .textFiles: "Text files"
        case .images: "Images"
        case .archives: "Archives"
        case .appleScripts: "AppleScripts"
        }
    }

    public var contentTypes: [String] {
        switch self {
        case .folders: ["public.folder"]
        case .documents: ["com.adobe.pdf", "public.composite-content", "public.presentation", "public.spreadsheet"]
        case .textFiles: ["public.plain-text"]
        case .images: ["public.image"]
        case .archives: ["public.archive"]
        case .appleScripts: ["com.apple.applescript.script", "com.apple.applescript.text", "com.apple.applescript.script-bundle"]
        }
    }
}

/// Spotlight query strings for file search. Every word matches at a word start
/// through the index ("rep" finds "Q3 report.pdf"); a leading wildcard would skip it.
public enum SpotlightPredicate {
    /// `open` and `find` match the name; `in` every word in the contents; `tags` every word in a tag.
    public static func string(for query: FileQuery, hiding: Set<HiddenKind> = []) -> String {
        let match: String
        switch query.mode {
        case .open, .reveal: match = clause("kMDItemFSName", query.text)
        case .inside: match = all("kMDItemTextContent", query.text)
        case .tags: match = all("kMDItemUserTags", query.text)
        }
        let types = hiding.sorted { $0.rawValue < $1.rawValue }.flatMap(\.contentTypes)
        return ([match] + types.map { "kMDItemContentTypeTree != \"\($0)\"" }).joined(separator: " && ")
    }

    /// A query without a keyword: names that match, of the ticked types only.
    public static func defaultResults(name: String, types: Set<ResultType>) -> String? {
        let tree = types.sorted { $0.rawValue < $1.rawValue }.flatMap(\.contentTypes)
        guard !tree.isEmpty else { return nil }
        let any = tree.map { "kMDItemContentTypeTree == \"\($0)\"" }.joined(separator: " || ")
        return "\(clause("kMDItemFSName", name)) && (\(any))"
    }

    private static func all(_ attribute: String, _ text: String) -> String {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let clauses = words.map { clause(attribute, $0) }
        return clauses.count == 1 ? clauses[0] : "(" + clauses.joined(separator: " && ") + ")"
    }

    private static func clause(_ attribute: String, _ text: String) -> String {
        "\(attribute) == \"\(escaped(text))*\"cdw"
    }

    /// Quotes and backslashes escaped; `*` dropped, since it is the wildcard.
    public static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "*", with: "")
    }
}

/// Folders inside the scope that file search leaves out: ~/Library, as in
/// Alfred, except iCloud Drive and the cloud storage folders (OneDrive, Dropbox).
/// Spotlight cannot filter on the path, so results are checked one by one.
public enum ScopeFilter {
    public static func keeps(_ path: String, home: String) -> Bool {
        let library = home + "/Library/"
        guard path.hasPrefix(library) else { return true }
        return path.hasPrefix(library + "Mobile Documents/") || path.hasPrefix(library + "CloudStorage/")
    }
}
