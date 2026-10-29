import Testing
@testable import ReachKit

@Test("Definitions come from the macOS dictionary service")
func dictionaryDefinition() {
    #expect(DictionaryLookup.definition(of: "apple")?.lowercased().hasPrefix("apple") == true)
    #expect(DictionaryLookup.definition(of: "xqzvwk") == nil)
    #expect(DictionaryLookup.definition(of: "  ") == nil)
}

@Test("The summary keeps the first sense, without headword or pronunciation")
func dictionarySummary() {
    let colour = "colour | 'kʌlə | ook: <Am> color znw 1 kleur, tint, verf ▸ local colour couleur locale 2 huidskleur"
    #expect(DictionaryLookup.summary(of: colour, word: "colour") == "ook: <Am> color znw kleur, tint, verf")
    let english = "serendipity | ˌserənˈdɪpɪti | noun the occurrence of events by chance in a happy way. ORIGIN 1754"
    #expect(DictionaryLookup.summary(of: english, word: "serendipity")
            == "noun the occurrence of events by chance in a happy way. ORIGIN 1754")
    #expect(DictionaryLookup.summary(of: "run 1 zelfstandig naamwoord gemalen eikenschors ", word: "run")
            == "zelfstandig naamwoord gemalen eikenschors")
    let long = "word " + String(repeating: "abc ", count: 60)
    let summary = DictionaryLookup.summary(of: long, word: "word")
    #expect(summary.count == DictionaryLookup.summaryLength && summary.hasSuffix("…"))
}

@Test("The word comes after the keyword and a space")
func dictionaryWord() {
    #expect(DictionaryLookup.word(in: "define seren", keyword: "define") == "seren")
    #expect(DictionaryLookup.word(in: "Define  Apple ", keyword: "define") == "Apple")
    #expect(DictionaryLookup.word(in: "define ", keyword: "define") == "")
    #expect(DictionaryLookup.word(in: "define", keyword: "define") == nil)
    #expect(DictionaryLookup.word(in: "defined", keyword: "define") == nil)
    #expect(DictionaryLookup.word(in: "spell x", keyword: "") == nil)
}

@Test("A lookup keyword cannot be empty, two words, or taken")
func dictionaryKeywordProblem() {
    #expect(DictionaryLookup.problem(keyword: "def", other: "spell") == nil)
    #expect(DictionaryLookup.problem(keyword: " ", other: "spell") == "Type a keyword.")
    #expect(DictionaryLookup.problem(keyword: "a b", other: "spell") == "A keyword is one word, without spaces.")
    #expect(DictionaryLookup.problem(keyword: "Spell", other: "spell") != nil)
    #expect(DictionaryLookup.problem(keyword: "sleep", other: "spell", taken: ["sleep": "Sleep"])
            == "“sleep” is already the keyword for Sleep.")
}
