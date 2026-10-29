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
