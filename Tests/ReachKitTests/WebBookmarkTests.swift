import Foundation
import Testing
@testable import ReachKit

/// Small bookmark files in the browsers' own formats; never a real one.
enum BookmarkFixtures {
    static let chrome = """
    {
      "checksum": "0",
      "roots": {
        "bookmark_bar": { "name": "Bookmarks bar", "type": "folder", "children": [
          { "name": "Swift Forums", "type": "url", "url": "https://forums.swift.org/" },
          { "name": "Docs", "type": "folder", "children": [
            { "name": "SwiftUI", "type": "url", "url": "https://developer.apple.com/documentation/swiftui" },
            { "name": "Bookmarklet", "type": "url", "url": "javascript:alert(1)" }
          ] }
        ] },
        "other": { "name": "Other bookmarks", "type": "folder", "children": [
          { "name": "", "type": "url", "url": "https://example.org/untitled" }
        ] },
        "synced": { "name": "Mobile bookmarks", "type": "folder", "children": [] }
      },
      "version": 1
    }
    """

    static let chromeWork = """
    { "roots": { "bookmark_bar": { "name": "Bookmarks bar", "type": "folder", "children": [
      { "name": "Jira", "type": "url", "url": "https://jira.example.com/" }
    ] } } }
    """

    static let safari = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>WebBookmarkType</key><string>WebBookmarkTypeList</string>
      <key>Title</key><string></string>
      <key>Children</key><array>
        <dict><key>WebBookmarkType</key><string>WebBookmarkTypeProxy</string><key>Title</key><string>History</string></dict>
        <dict>
          <key>WebBookmarkType</key><string>WebBookmarkTypeList</string>
          <key>Title</key><string>BookmarksBar</string>
          <key>Children</key><array>
            <dict>
              <key>WebBookmarkType</key><string>WebBookmarkTypeLeaf</string>
              <key>URLString</key><string>https://www.apple.com/</string>
              <key>URIDictionary</key><dict><key>title</key><string>Apple</string></dict>
            </dict>
            <dict>
              <key>WebBookmarkType</key><string>WebBookmarkTypeLeaf</string>
              <key>URLString</key><string>https://FORUMS.swift.org</string>
              <key>URIDictionary</key><dict><key>title</key><string>Swift Forums (Safari)</string></dict>
            </dict>
          </array>
        </dict>
        <dict>
          <key>WebBookmarkType</key><string>WebBookmarkTypeList</string>
          <key>Title</key><string>BookmarksMenu</string>
          <key>Children</key><array>
            <dict>
              <key>WebBookmarkType</key><string>WebBookmarkTypeList</string>
              <key>Title</key><string>News</string>
              <key>Children</key><array>
                <dict>
                  <key>WebBookmarkType</key><string>WebBookmarkTypeLeaf</string>
                  <key>URLString</key><string>https://nos.nl/</string>
                  <key>URIDictionary</key><dict><key>title</key><string>NOS</string></dict>
                </dict>
              </array>
            </dict>
          </array>
        </dict>
        <dict>
          <key>WebBookmarkType</key><string>WebBookmarkTypeList</string>
          <key>Title</key><string>com.apple.ReadingList</string>
          <key>Children</key><array>
            <dict>
              <key>WebBookmarkType</key><string>WebBookmarkTypeLeaf</string>
              <key>URLString</key><string>https://example.com/read-later</string>
              <key>URIDictionary</key><dict><key>title</key><string>Read later</string></dict>
            </dict>
          </array>
        </dict>
      </array>
    </dict></plist>
    """
}

struct WebBookmarkTests {
    @Test func chromeReadsEveryURLWithItsFolder() throws {
        let marks = try WebBookmarks.chrome(Data(BookmarkFixtures.chrome.utf8))
        #expect(marks.map(\.title) == ["Swift Forums", "SwiftUI", "example.org/untitled"])
        #expect(marks.map(\.folder) == ["Bookmarks bar", "Bookmarks bar › Docs", "Other bookmarks"])
        #expect(marks.allSatisfy { $0.browser == .chrome })
    }

    @Test func chromeSkipsBookmarklets() throws {
        let marks = try WebBookmarks.chrome(Data(BookmarkFixtures.chrome.utf8))
        #expect(!marks.contains { $0.url.hasPrefix("javascript:") })
    }

    @Test func safariReadsFavoritesAndMenuButNotTheReadingList() throws {
        let marks = try WebBookmarks.safari(Data(BookmarkFixtures.safari.utf8))
        #expect(marks.map(\.title) == ["Apple", "Swift Forums (Safari)", "NOS"])
        #expect(marks.map(\.folder) == ["Favorites", "Favorites", "Bookmarks Menu › News"])
        #expect(marks.allSatisfy { $0.browser == .safari })
    }

    @Test func otherFilesAreUnreadable() {
        #expect(throws: WebBookmarks.ReadError.unreadable) { try WebBookmarks.chrome(Data("not json".utf8)) }
        #expect(throws: WebBookmarks.ReadError.unreadable) { try WebBookmarks.safari(Data("{}".utf8)) }
    }

    @Test func everyChromeProfileIsFound() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "reach-chrome-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        for (profile, file) in [("Profile 2", BookmarkFixtures.chromeWork), ("Default", BookmarkFixtures.chrome),
                                ("Profile 10", BookmarkFixtures.chromeWork), ("System Profile", nil)] {
            let folder = root.appending(path: profile)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if let file { try Data(file.utf8).write(to: folder.appending(path: "Bookmarks")) }
        }
        let profiles = WebBookmarks.chromeProfiles(in: root).map { $0.deletingLastPathComponent().lastPathComponent }
        #expect(profiles == ["Default", "Profile 2", "Profile 10"])
        #expect(WebBookmarks.chromeProfiles(in: root.appending(path: "missing")).isEmpty)
    }

    @Test func aBookmarkInBothBrowsersCountsOnce() throws {
        let safari = try WebBookmarks.safari(Data(BookmarkFixtures.safari.utf8))
        let chrome = try WebBookmarks.chrome(Data(BookmarkFixtures.chrome.utf8))
        let merged = WebBookmarks.merge([safari, chrome])
        #expect(merged.count == safari.count + chrome.count - 1)
        // The first one read wins: Safari's title for the forums.
        #expect(merged.filter { $0.key == "https://forums.swift.org" }.map(\.title) == ["Swift Forums (Safari)"])
    }

    @Test func keyIgnoresCaseOfHostAndTrailingSlash() {
        let a = WebBookmark(title: "", url: "HTTPS://Example.com/", browser: .chrome)
        let b = WebBookmark(title: "", url: "https://example.com", browser: .safari)
        #expect(a.key == b.key)
        let path = WebBookmark(title: "", url: "https://example.com/Docs", browser: .safari)
        #expect(path.key != WebBookmark(title: "", url: "https://example.com/docs", browser: .safari).key)
    }

    @Test func matchesTitleAndAddressWithTheLauncherRanking() {
        let marks = [WebBookmark(title: "Swift Forums", url: "https://forums.swift.org/", browser: .chrome),
                     WebBookmark(title: "NOS", url: "https://nos.nl/", browser: .safari),
                     WebBookmark(title: "Apple", url: "https://www.apple.com/", browser: .safari)]
        #expect(WebBookmarks.matches("swift", in: marks).map(\.bookmark.title) == ["Swift Forums"])
        #expect(WebBookmarks.matches("nos.nl", in: marks).first?.bookmark.title == "NOS")
        #expect(WebBookmarks.matches("apple.com", in: marks).first?.bookmark.title == "Apple")
        let score = WebBookmarks.matches("swift forums", in: marks).first?.score
        #expect(score == Matcher.score(query: "swift forums", title: "Swift Forums"))
        #expect(WebBookmarks.matches("zzz", in: marks).isEmpty)
    }

    @Test func keywordAlwaysSearchesDefaultResultsOnlyWhenSet() {
        #expect(WebBookmarks.searchText(in: "bm swift", mode: .keywordOnly) == "swift")
        #expect(WebBookmarks.searchText(in: "bm swift", mode: .defaultResults) == "swift")
        #expect(WebBookmarks.searchText(in: "swift", mode: .keywordOnly) == nil)
        #expect(WebBookmarks.searchText(in: "swift", mode: .defaultResults) == "swift")
        #expect(WebBookmarks.searchText(in: "s", mode: .defaultResults) == nil)
        #expect(WebBookmarks.searchText(in: "BM nos", mode: .keywordOnly) == "nos")
    }

    @Test func addressDropsTheSchemeAndALoneSlash() {
        #expect(WebBookmark(title: "", url: "https://nos.nl/", browser: .safari).address == "nos.nl")
        #expect(WebBookmark(title: "", url: "https://a.b/c/", browser: .safari).address == "a.b/c/")
    }
}
