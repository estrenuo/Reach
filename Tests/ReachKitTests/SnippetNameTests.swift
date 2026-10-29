import Foundation
import Testing
@testable import ReachKit

@Test("Clean names", arguments: [
    ("Email signature", "Email signature"),
    ("  Email   signature \n", "Email signature"),
    ("", "New Snippet"),
    ("   ", "New Snippet"),
])
func cleans(_ input: String, expected: String) {
    #expect(SnippetName.clean(input) == expected)
}

@Test func collectionNamesFallBack() {
    #expect(SnippetName.clean("  ", fallback: "New Collection") == "New Collection")
    #expect(SnippetName.clean(" Work  mail ", fallback: "New Collection") == "Work mail")
}

@Test func keywordsAreOneWord() {
    #expect(SnippetName.keyword(" s ig\n") == "sig")
}

@Test func snippetsAreFoundByNameOrKeyword() {
    #expect(SnippetSearch.score("sig", name: "Email signature", keyword: "sig") == 1100)
    #expect(SnippetSearch.score("email", name: "Email signature", keyword: "sig") != nil)
    #expect(SnippetSearch.score("addr", name: "Home", keyword: "addr1") != nil)
    #expect(SnippetSearch.score("zzq", name: "Email signature", keyword: "sig") == nil)
    #expect(SnippetSearch.score("  ", name: "Email signature", keyword: "sig") == nil)
    // The full keyword wins over a name that starts with it.
    let keyword = SnippetSearch.score("addr", name: "Home", keyword: "addr") ?? 0
    let name = SnippetSearch.score("addr", name: "Address book", keyword: "") ?? 0
    #expect(keyword > name)
}

@Test func placeholdersAreFilledIn() {
    let date = Date(timeIntervalSince1970: 1_793_282_700)  // 29 Oct 2026, 14:05 UTC
    let utc = TimeZone(identifier: "UTC")!
    let en = Locale(identifier: "en_GB")
    let filled = SnippetText.expand("On {date} at {time}: {clipboard}", date: date, clipboard: "hello", locale: en, timeZone: utc)
    #expect(filled == "On 29 Oct 2026 at 14:05: hello")
    // Clipboard text is not filled in a second time.
    #expect(SnippetText.expand("{clipboard}", date: date, clipboard: "{date}", locale: en, timeZone: utc) == "{date}")
    #expect(SnippetText.expand("{clipboard}!", date: date, clipboard: nil) == "!")
    #expect(SnippetText.expand("{name} and {}", date: date, clipboard: "x") == "{name} and {}")
}

@Test func previewIsTheFirstLine() {
    #expect(SnippetText.preview("  Met vriendelijke groet,\nSander") == "Met vriendelijke groet,")
    #expect(SnippetText.preview("") == "")
    #expect(SnippetText.preview(String(repeating: "a", count: 200)).count == 121)
}
