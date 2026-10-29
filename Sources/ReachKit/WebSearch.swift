import Foundation

/// A web search with a keyword (S-016): `wiki alfred` searches Wikipedia.
/// The URL holds `{query}` where the words go; without it the search is a
/// bookmark that the keyword alone opens ("Open Gmail").
public struct WebSearch: Codable, Equatable, Identifiable, Sendable {
    /// The built-in's name ("wiki"), or a UUID for a custom search.
    public var id: String
    public var keyword: String
    /// What the result row says, with `{query}` for the words: "Search Wikipedia for “{query}”".
    public var title: String
    public var url: String
    public var symbol: String
    public var isOn: Bool
    public var isBuiltIn: Bool

    public init(id: String = UUID().uuidString, keyword: String, title: String, url: String,
                symbol: String = "globe", isOn: Bool = true, isBuiltIn: Bool = false) {
        self.id = id
        self.keyword = keyword
        self.title = title
        self.url = url
        self.symbol = symbol
        self.isOn = isOn
        self.isBuiltIn = isBuiltIn
    }

    public var takesQuery: Bool { url.contains("{query}") }

    /// The row's title for `text`; "…" stands in while no words are typed.
    public func title(for text: String) -> String {
        title.replacingOccurrences(of: "{query}", with: text.isEmpty ? "…" : text)
    }

    /// The site's front page, for a keyword with nothing after it.
    public var homepage: URL? {
        guard let parts = URLComponents(string: url.replacingOccurrences(of: "{query}", with: "")),
              let scheme = parts.scheme, let host = parts.host else { return nil }
        return URL(string: "\(scheme)://\(host)/")
    }
}

public enum WebSearches {
    /// A row for one search, for what the query says.
    public struct Match: Equatable, Sendable {
        public let search: WebSearch
        /// The words after the keyword; empty when there are none yet.
        public let text: String
        /// True once the keyword and a space are typed.
        public let typedKeyword: Bool
        /// The `Matcher` scale: words after a keyword beat any app; a part of a keyword ranks below apps that start with it.
        public let score: Int

        public var title: String { search.title(for: text) }

        /// What Return opens; nil when Return completes the keyword instead.
        public var url: URL? {
            guard search.takesQuery else { return URL(string: search.url) }
            guard !text.isEmpty else { return typedKeyword ? search.homepage : nil }
            return WebSearchURL.make(template: search.url, query: text)
        }

        /// The query Return puts in the search field: "wik" becomes "wiki ".
        public var completion: String? {
            search.takesQuery && !typedKeyword ? search.keyword + " " : nil
        }
    }

    /// The searches `query` asks for. Searches that are off never match,
    /// so their keyword is an ordinary query and can fall through to the fallbacks.
    public static func matches(_ query: String, in searches: [WebSearch]) -> [Match] {
        let lowered = query.lowercased()
        return searches.filter(\.isOn).compactMap { search in
            let keyword = search.keyword.lowercased()
            if lowered.hasPrefix(keyword + " ") {
                let text = String(query.dropFirst(keyword.count + 1)).trimmingCharacters(in: .whitespaces)
                // A bookmark has no words to take.
                guard search.takesQuery || text.isEmpty else { return nil }
                return Match(search: search, text: text, typedKeyword: true, score: 2000)
            }
            guard !lowered.isEmpty, !lowered.contains(" "), keyword.hasPrefix(lowered) else { return nil }
            return Match(search: search, text: "", typedKeyword: false, score: lowered == keyword ? 900 : 700)
        }
    }

    /// Why a custom search cannot be saved, or nil when it can. `taken` holds
    /// keywords other features use, with the feature's name.
    public static func problem(title: String, keyword: String, url: String, taken: [String: String] = [:]) -> String? {
        if title.trimmingCharacters(in: .whitespaces).isEmpty { return "Type a title." }
        if keyword.isEmpty { return "Type a keyword." }
        if keyword.contains(where: \.isWhitespace) { return "A keyword is one word, without spaces." }
        if let feature = taken[keyword.lowercased()] { return "“\(keyword)” is already the keyword for \(feature)." }
        let filled = url.replacingOccurrences(of: "{query}", with: "x")
        guard let parts = URLComponents(string: filled), let scheme = parts.scheme?.lowercased(),
              scheme != "file", parts.host?.isEmpty == false || !["http", "https"].contains(scheme)
        else { return "Type a URL that starts with https://." }
        return nil
    }

    /// Alfred's list. The ones on at first are the ones Sander uses in Alfred.
    public static let builtIn: [WebSearch] = [
        search("google", "google", "Search Google for “{query}”", "https://www.google.com/search?q={query}", "magnifyingglass"),
        search("lucky", "lucky", "I’m feeling lucky for “{query}”", "https://www.google.com/search?btnI=1&q={query}", "dice"),
        search("images", "images", "Search Google Images for “{query}”", "https://www.google.com/search?tbm=isch&q={query}", "photo"),
        search("googlemaps", "maps", "Search Google Maps for “{query}”", "https://www.google.com/maps/search/{query}", "map"),
        search("applemaps", "maps", "Search Apple Maps for “{query}”", "https://maps.apple.com/?q={query}", "map.fill", on: true),
        search("translate", "translate", "Translate “{query}”", "https://translate.google.com/?text={query}", "character.bubble", on: true),
        search("gmail", "gmail", "Open Gmail", "https://mail.google.com/", "envelope"),
        search("gmailsearch", "gmail", "Search Gmail for “{query}”", "https://mail.google.com/mail/u/0/#search/{query}", "envelope"),
        search("drive", "drive", "Open Google Drive", "https://drive.google.com/", "externaldrive"),
        search("drivesearch", "drive", "Search Google Drive for “{query}”", "https://drive.google.com/drive/search?q={query}", "externaldrive"),
        search("x", "x", "Open X", "https://x.com/", "at"),
        search("xsearch", "x", "Search X for “{query}”", "https://x.com/search?q={query}", "at"),
        search("xuser", "x", "Open X user “{query}”", "https://x.com/{query}", "person"),
        search("wiki", "wiki", "Search Wikipedia for “{query}”", "https://en.wikipedia.org/wiki/Special:Search?search={query}", "book", on: true),
        search("amazon", "amazon", "Search Amazon for “{query}”", "https://www.amazon.com/s?k={query}", "cart", on: true),
        search("imdb", "imdb", "Search IMDb for “{query}”", "https://www.imdb.com/find?q={query}", "film", on: true),
        search("ebay", "ebay", "Search eBay for “{query}”", "https://www.ebay.com/sch/i.html?_nkw={query}", "tag"),
        search("bing", "bing", "Search Bing for “{query}”", "https://www.bing.com/search?q={query}", "magnifyingglass"),
        search("yahoo", "yahoo", "Search Yahoo for “{query}”", "https://search.yahoo.com/search?p={query}", "magnifyingglass"),
        search("ask", "ask", "Search Ask for “{query}”", "https://www.ask.com/web?q={query}", "questionmark.bubble"),
        search("linkedin", "linkedin", "Search LinkedIn for “{query}”", "https://www.linkedin.com/search/results/all/?keywords={query}", "person.2", on: true),
        search("youtube", "youtube", "Search YouTube for “{query}”", "https://www.youtube.com/results?search_query={query}", "play.rectangle", on: true),
        search("facebook", "facebook", "Search Facebook for “{query}”", "https://www.facebook.com/search/top/?q={query}", "person.3"),
        search("flickr", "flickr", "Search Flickr for “{query}”", "https://www.flickr.com/search/?q={query}", "photo.on.rectangle"),
        search("wolfram", "wolfram", "Ask Wolfram for “{query}”", "https://www.wolframalpha.com/input/?i={query}", "function", on: true),
        search("yubnub", "yubnub", "Search YubNub for “{query}”", "https://yubnub.org/parser/parse?command={query}", "terminal"),
    ]

    private static func search(_ id: String, _ keyword: String, _ title: String, _ url: String, _ symbol: String,
                               on: Bool = false) -> WebSearch {
        WebSearch(id: id, keyword: keyword, title: title, url: url, symbol: symbol, isOn: on, isBuiltIn: true)
    }
}
