import Testing
@testable import ReachKit

@Test("Fallbacks keep their order, and leave out searches that are gone or take no words")
func fallbackSearches() {
    let ids = ["wiki", "gone", "gmail", "google"]
    #expect(FallbackList.searches(ids: ids, from: WebSearches.builtIn).map(\.id) == ["wiki", "google"])
    #expect(FallbackList.searches(ids: FallbackList.standard, from: WebSearches.builtIn).map(\.id) == ["google", "amazon", "wiki"])
}

@Test("A search whose keyword is off can still be a fallback")
func fallbackKeywordOff() {
    let google = WebSearches.builtIn.first { $0.id == "google" }!
    #expect(!google.isOn)
    #expect(FallbackList.searches(ids: ["google"], from: [google]).count == 1)
}

@Test("Add offers searches that take words and are not fallbacks yet")
func fallbackChoices() {
    let choices = FallbackList.choices(ids: FallbackList.standard, from: WebSearches.builtIn).map(\.id)
    #expect(!choices.contains("google") && !choices.contains("gmail") && choices.contains("youtube"))
}

@Test("Only when there are no results: fallbacks show for an empty list alone")
func fallbackNoResults() {
    #expect(FallbackList.split(found: 0, fallbacks: 3, mode: .noResults) == (0, 3))
    #expect(FallbackList.split(found: 4, fallbacks: 3, mode: .noResults) == (4, 0))
    #expect(FallbackList.split(found: 12, fallbacks: 3, mode: .noResults) == (9, 0))
}

@Test("Always: fallbacks sit below the results and keep their rows within nine")
func fallbackAlways() {
    #expect(FallbackList.split(found: 4, fallbacks: 3, mode: .always) == (4, 3))
    #expect(FallbackList.split(found: 9, fallbacks: 3, mode: .always) == (6, 3))
    #expect(FallbackList.split(found: 0, fallbacks: 3, mode: .always) == (0, 3))
    #expect(FallbackList.split(found: 5, fallbacks: 12, mode: .always) == (0, 9))
}
