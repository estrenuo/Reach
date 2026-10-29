import Foundation
import Testing
@testable import ReachKit

private let wiki = WebSearches.builtIn.first { $0.id == "wiki" }!
private let gmail: WebSearch = { var search = WebSearches.builtIn.first { $0.id == "gmail" }!; search.isOn = true; return search }()

@Test("The keyword and a space search the site for the words after it")
func webSearchKeyword() {
    let match = WebSearches.matches("wiki alfred app", in: [wiki]).first
    #expect(match?.title == "Search Wikipedia for “alfred app”")
    #expect(match?.url?.absoluteString == "https://en.wikipedia.org/wiki/Special:Search?search=alfred%20app")
    #expect(match?.completion == nil)
    #expect(match?.score == 2000)
    #expect(WebSearches.matches("WIKI Alfred", in: [wiki]).first?.text == "Alfred")
}

@Test("A disabled keyword falls through: it matches nothing, so the fallbacks show")
func webSearchDisabled() {
    var off = WebSearches.builtIn.first { $0.id == "google" }!
    #expect(!off.isOn)
    #expect(WebSearches.matches("google alfred app", in: [off]).isEmpty)
    off.isOn = true
    #expect(WebSearches.matches("google alfred app", in: [off]).count == 1)
}

@Test("Part of a keyword offers the search; Return completes the keyword")
func webSearchPartial() {
    let partial = WebSearches.matches("wik", in: [wiki]).first
    #expect(partial?.title == "Search Wikipedia for “…”")
    #expect(partial?.url == nil && partial?.completion == "wiki ")
    #expect(partial?.score == 700)
    #expect(WebSearches.matches("wiki", in: [wiki]).first?.score == 900)
    #expect(WebSearches.matches("ikipedia", in: [wiki]).isEmpty)
    #expect(WebSearches.matches("", in: [wiki]).isEmpty)
}

@Test("The keyword with a space and no words opens the site's front page")
func webSearchHomepage() {
    let match = WebSearches.matches("wiki ", in: [wiki]).first
    #expect(match?.url?.absoluteString == "https://en.wikipedia.org/")
}

@Test("A search without {query} is a bookmark the keyword opens, and takes no words")
func webSearchBookmark() {
    #expect(!gmail.takesQuery)
    #expect(WebSearches.matches("gma", in: [gmail]).first?.url?.absoluteString == "https://mail.google.com/")
    #expect(WebSearches.matches("gmail ", in: [gmail]).first?.url?.absoluteString == "https://mail.google.com/")
    #expect(WebSearches.matches("gmail invoice", in: [gmail]).isEmpty)
}

@Test("Two searches can share a keyword")
func webSearchSharedKeyword() {
    let maps = WebSearches.builtIn.filter { $0.keyword == "maps" }.map { var s = $0; s.isOn = true; return s }
    #expect(WebSearches.matches("maps utrecht", in: maps).map(\.title)
            == ["Search Google Maps for “utrecht”", "Search Apple Maps for “utrecht”"])
}

@Test("A custom search needs a title, one free word, and a web URL")
func webSearchProblems() {
    let url = "https://example.com/?q={query}"
    #expect(WebSearches.problem(title: "Example", keyword: "ex", url: url) == nil)
    #expect(WebSearches.problem(title: " ", keyword: "ex", url: url) == "Type a title.")
    #expect(WebSearches.problem(title: "Example", keyword: "", url: url) == "Type a keyword.")
    #expect(WebSearches.problem(title: "Example", keyword: "e x", url: url) == "A keyword is one word, without spaces.")
    #expect(WebSearches.problem(title: "Example", keyword: "In", url: url, taken: ["in": "Search inside files"])
            == "“In” is already the keyword for Search inside files.")
    #expect(WebSearches.problem(title: "Example", keyword: "ex", url: "example.com") == "Type a URL that starts with https://.")
    #expect(WebSearches.problem(title: "Example", keyword: "ex", url: "https://") == "Type a URL that starts with https://.")
    #expect(WebSearches.problem(title: "Example", keyword: "ex", url: "file:///etc/{query}") == "Type a URL that starts with https://.")
    #expect(WebSearches.problem(title: "Spotify", keyword: "sp", url: "spotify:search:{query}") == nil)
}

@Test("Every built-in has a unique id and a URL that works; the eight Sander uses are on")
func webSearchBuiltIns() {
    let all = WebSearches.builtIn
    #expect(Set(all.map(\.id)).count == all.count)
    #expect(all.allSatisfy { WebSearches.problem(title: $0.title, keyword: $0.keyword, url: $0.url) == nil })
    #expect(Set(all.filter(\.isOn).map(\.id))
            == ["applemaps", "translate", "wiki", "amazon", "imdb", "linkedin", "youtube", "wolfram"])
}
