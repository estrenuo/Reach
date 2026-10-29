import Foundation
import Testing
@testable import ReachKit

@Test("Each file keyword picks its mode", arguments: [
    ("find report", FileQuery(.reveal, "report")),
    ("in rabbit hat", FileQuery(.inside, "rabbit hat")),
    ("tags work", FileQuery(.tags, "work")),
    ("Tags ", FileQuery(.tags, "")),
])
func fileKeywords(_ query: String, expected: FileQuery) {
    #expect(QueryKind(query) == .files(expected))
}

@Test("A keyword counts only with a space after it")
func keywordNeedsSpace() {
    #expect(QueryKind("inbox") == .normal("inbox"))
    #expect(QueryKind("finder") == .normal("finder"))
}

@Test("A renamed keyword replaces the old word; one that is off is a normal search")
func renamedAndOff() {
    var keywords = FileKeywords()
    keywords[.reveal].word = "reveal"
    keywords[.inside].isOn = false
    #expect(QueryKind("reveal report", keywords: keywords) == .files(FileQuery(.reveal, "report")))
    #expect(QueryKind("find report", keywords: keywords) == .normal("find report"))
    #expect(QueryKind("in rabbit", keywords: keywords) == .normal("in rabbit"))
    // The quick prefixes still open files.
    keywords[.open].isOn = false
    #expect(QueryKind("'rep", keywords: keywords) == .files(FileQuery(.open, "rep")))
}

@Test("A keyword must be one free word")
func keywordProblems() {
    let keywords = FileKeywords()
    #expect(keywords.problem(with: "", for: .open) == "Type a keyword.")
    #expect(keywords.problem(with: "my files", for: .open) == "A keyword is one word, without spaces.")
    #expect(keywords.problem(with: "~x", for: .open) != nil)
    #expect(keywords.problem(with: "find", for: .open) == "“find” is already the keyword for Reveal in Finder.")
    #expect(keywords.problem(with: "find", for: .reveal) == nil)
    #expect(keywords.problem(with: "go", for: .open) == nil)
}

@Test("find reveals in Finder; the others open")
func findReveals() {
    #expect(FileQuery(.reveal, "x").reveals)
    #expect(!FileQuery(.open, "x").reveals && !FileQuery(.inside, "x").reveals && !FileQuery(.tags, "x").reveals)
}

@Test("open and find match the name; in matches the contents; tags the Finder tags")
func predicates() {
    #expect(SpotlightPredicate.string(for: FileQuery(.open, "rep")) == #"kMDItemFSName == "rep*"cdw"#)
    #expect(SpotlightPredicate.string(for: FileQuery(.reveal, "rep")) == #"kMDItemFSName == "rep*"cdw"#)
    #expect(SpotlightPredicate.string(for: FileQuery(.inside, "rabbit hat"))
            == #"(kMDItemTextContent == "rabbit*"cdw && kMDItemTextContent == "hat*"cdw)"#)
    #expect(SpotlightPredicate.string(for: FileQuery(.tags, "work")) == #"kMDItemUserTags == "work*"cdw"#)
}

@Test("Don't Show leaves the kind's content types out")
func hiding() {
    let predicate = SpotlightPredicate.string(for: FileQuery(.open, "a"), hiding: [.images, .plists])
    #expect(predicate == #"kMDItemFSName == "a*"cdw && kMDItemContentTypeTree != "public.image" && kMDItemContentTypeTree != "com.apple.property-list""#)
}

@Test("Default results ask Spotlight only when a type is ticked")
func defaultResults() {
    #expect(SpotlightPredicate.defaultResults(name: "dev", types: []) == nil)
    #expect(SpotlightPredicate.defaultResults(name: "dev", types: [.folders])
            == #"kMDItemFSName == "dev*"cdw && (kMDItemContentTypeTree == "public.folder")"#)
}

@Test("Quotes and wildcards in the query cannot break the predicate")
func escaping() {
    #expect(SpotlightPredicate.escaped(#"a"b*\"#) == #"a\"b\\"#)
}
