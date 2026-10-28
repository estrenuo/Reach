import Foundation
import Testing
@testable import ReachKit

@Test("Matches word starts and initials", arguments: [
    ("vsc", "Visual Studio Code"),
    ("vscode", "Visual Studio Code"),
    ("code", "Visual Studio Code"),
    ("saf", "Safari"),
    ("cafe", "Café Racer"),
    ("sysset", "System Settings"),
])
func matches(_ query: String, title: String) {
    #expect(Matcher.score(query: query, title: title) != nil)
}

@Test("No match for unrelated letters")
func noMatch() {
    #expect(Matcher.score(query: "xyz", title: "Safari") == nil)
    #expect(Matcher.score(query: "", title: "Safari") == nil)
}

@Test("A prefix ranks above a word start, which ranks above a substring")
func ordering() throws {
    let prefix = try #require(Matcher.score(query: "co", title: "Console"))
    let word = try #require(Matcher.score(query: "co", title: "Visual Studio Code"))
    let inside = try #require(Matcher.score(query: "co", title: "Facetime Recorder"))
    #expect(prefix > word)
    #expect(word > inside)
}

@Test("Matching 500 apps on every keystroke stays under 50 ms")
func speed() {
    let titles = (0..<500).map { "Application Number \($0) Helper" }
    let start = Date.now
    for query in ["a", "ap", "app", "anh", "help"] {
        _ = titles.compactMap { Matcher.score(query: query, title: $0) }
    }
    #expect(Date.now.timeIntervalSince(start) / 5 < 0.05)
}

@Test("Reads the file keyword", arguments: [
    ("", QueryKind.empty),
    ("saf", .normal("saf")),
    ("open report", .files("report")),
    ("Open ", .files("")),
    ("'rep", .files("rep")),
    (" rep", .files("rep")),
    ("opener", .normal("opener")),
])
func queryKind(_ query: String, expected: QueryKind) {
    #expect(QueryKind(query) == expected)
}

@Test("Web search URL-encodes the query")
func webSearch() {
    let url = WebSearchURL.make(template: "https://www.google.com/search?q={query}", query: "a&b c/ö")
    #expect(url?.absoluteString == "https://www.google.com/search?q=a%26b%20c%2F%C3%B6")
}

@Test("Hotkey display and validity")
func hotkey() {
    #expect(KeyCombo.default.display(key: "Space") == "⌃⌥Space")
    #expect(KeyCombo.default.spoken(key: "Space") == "Control Option Space")
    #expect(!KeyCombo(keyCode: 0, modifiers: KeyCombo.shift).isValid)
}

@Test("The text after the keyword")
func queryText() {
    #expect(QueryKind("open report").text == "report")
    #expect(QueryKind("saf").text == "saf")
    #expect(QueryKind("").text == "")
}
