import Foundation

/// The browser a web bookmark came from (S-057).
public enum BookmarkBrowser: String, CaseIterable, Sendable {
    case safari, chrome

    public var bundleID: String {
        switch self {
        case .safari: "com.apple.Safari"
        case .chrome: "com.google.Chrome"
        }
    }

    public var title: String {
        switch self {
        case .safari: "Safari"
        case .chrome: "Google Chrome"
        }
    }
}

/// One web bookmark from Safari or Chrome: its title, address and folder.
public struct WebBookmark: Equatable, Sendable {
    public var title: String
    public var url: String
    /// The folders it sits in, joined with " › ", like "Favorites › Docs".
    public var folder: String
    public var browser: BookmarkBrowser

    public init(title: String, url: String, folder: String = "", browser: BookmarkBrowser) {
        self.title = title
        self.url = url
        self.folder = folder
        self.browser = browser
    }

    /// The address as people read it: without `https://` and a lone trailing slash.
    public var address: String { TypedURL.display(url) }

    /// Two bookmarks with the same key are the same page: scheme and host
    /// ignore case, and a trailing slash is dropped.
    public var key: String {
        guard var parts = URLComponents(string: url) else { return url }
        parts.scheme = parts.scheme?.lowercased()
        parts.host = parts.host?.lowercased()
        var text = parts.string ?? url
        if text.hasSuffix("/") { text.removeLast() }
        return text
    }
}

/// Where bookmarks show: among the default results, or only after the keyword.
public enum BookmarkShowMode: String, CaseIterable, Sendable {
    case defaultResults, keywordOnly
}

/// Reads Chrome's and Safari's bookmark files, and matches a query against them (S-057).
public enum WebBookmarks {
    public static let keyword = "bm"
    /// Fewer letters than this find no bookmark among the default results.
    public static let minimumLetters = 2

    public enum ReadError: Error, Equatable {
        /// The file is not in the format we know.
        case unreadable
    }

    // MARK: Chrome

    /// Chrome's `Bookmarks` file (JSON): every URL under the roots, with its folder.
    public static func chrome(_ data: Data) throws -> [WebBookmark] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let roots = json["roots"] as? [String: Any] else { throw ReadError.unreadable }
        var found: [WebBookmark] = []
        func walk(_ node: [String: Any], path: [String]) {
            let name = node["name"] as? String ?? ""
            switch node["type"] as? String {
            case "url":
                if let url = node["url"] as? String, isWeb(url) {
                    found.append(WebBookmark(title: name.isEmpty ? TypedURL.display(url) : name, url: url,
                                             folder: path.joined(separator: " › "), browser: .chrome))
                }
            case "folder":
                let children = node["children"] as? [[String: Any]] ?? []
                children.forEach { walk($0, path: path + [name].filter { !$0.isEmpty }) }
            default:
                break
            }
        }
        // The roots in the order Chrome shows them; `sync_transaction_version` and the like are skipped.
        for key in ["bookmark_bar", "other", "synced"] {
            if let root = roots[key] as? [String: Any] { walk(root, path: []) }
        }
        return found
    }

    /// The `Bookmarks` file of every Chrome profile under `root`
    /// (`~/Library/Application Support/Google/Chrome`): Default, Profile 1, …
    public static func chromeProfiles(in root: URL, fileManager: FileManager = .default) -> [URL] {
        let names = (try? fileManager.contentsOfDirectory(atPath: root.path)) ?? []
        return names.sorted { a, b in
            // Default first, then the profiles in their own order.
            a == "Default" || (b != "Default" && a.localizedStandardCompare(b) == .orderedAscending)
        }
        .map { root.appending(path: $0).appending(path: "Bookmarks") }
        .filter { fileManager.fileExists(atPath: $0.path) }
    }

    // MARK: Safari

    /// Safari's `Bookmarks.plist`: Favorites, the Bookmarks Menu and their
    /// folders. The Reading List and History are not bookmarks and stay out.
    public static func safari(_ data: Data) throws -> [WebBookmark] {
        guard let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              root["WebBookmarkType"] as? String == "WebBookmarkTypeList" else { throw ReadError.unreadable }
        var found: [WebBookmark] = []
        func walk(_ node: [String: Any], path: [String]) {
            switch node["WebBookmarkType"] as? String {
            case "WebBookmarkTypeLeaf":
                guard let url = node["URLString"] as? String, isWeb(url) else { return }
                let title = (node["URIDictionary"] as? [String: Any])?["title"] as? String ?? ""
                found.append(WebBookmark(title: title.isEmpty ? TypedURL.display(url) : title, url: url,
                                         folder: path.joined(separator: " › "), browser: .safari))
            case "WebBookmarkTypeList":
                let title = node["Title"] as? String ?? ""
                if title == "com.apple.ReadingList" { return }
                let children = node["Children"] as? [[String: Any]] ?? []
                children.forEach { walk($0, path: path + [safariFolder(title)].filter { !$0.isEmpty }) }
            default:
                break
            }
        }
        walk(root, path: [])
        return found
    }

    /// Safari's internal names for its two top folders, as Safari shows them.
    private static func safariFolder(_ title: String) -> String {
        switch title {
        case "BookmarksBar": "Favorites"
        case "BookmarksMenu": "Bookmarks Menu"
        default: title
        }
    }

    // MARK: Merging and matching

    /// One list from several: a page bookmarked twice (in both browsers, or in
    /// two folders) counts once, as the first one read.
    public static func merge(_ lists: [[WebBookmark]]) -> [WebBookmark] {
        var seen: Set<String> = []
        return lists.joined().filter { seen.insert($0.key).inserted }
    }

    /// The text to look for in the bookmarks, or nil when this query is not
    /// for bookmarks: `bm <text>` always, any other query only with the
    /// bookmarks among the default results.
    public static func searchText(in query: String, mode: BookmarkShowMode, keyword: String = keyword) -> String? {
        if let words = DictionaryLookup.word(in: query, keyword: keyword) { return words }
        guard mode == .defaultResults, query.count >= minimumLetters else { return nil }
        return query
    }

    /// The bookmarks that match `text` on their title or address, best first,
    /// scored like every other result (`Matcher`).
    public static func matches(_ text: String, in bookmarks: [WebBookmark]) -> [(bookmark: WebBookmark, score: Int)] {
        bookmarks.compactMap { bookmark -> (WebBookmark, Int)? in
            let score = [Matcher.score(query: text, title: bookmark.title),
                         Matcher.score(query: text, title: bookmark.address)].compactMap { $0 }.max()
            return score.map { (bookmark, $0) }
        }
        .sorted { $0.1 > $1.1 }
    }

    /// Only web pages: bookmarklets (`javascript:`) and other schemes stay out.
    static func isWeb(_ url: String) -> Bool {
        let lower = url.lowercased()
        return lower.hasPrefix("https://") || lower.hasPrefix("http://")
    }
}

/// Which browser Return opens a bookmark in.
public enum BookmarkOpenMode: String, CaseIterable, Sendable {
    /// The Mac's default web browser.
    case defaultBrowser
    /// The browser the bookmark came from.
    case sourceBrowser
}
