import Testing
@testable import ReachKit

@Test func controlUpWalksToOlderQueriesAndDownComesBack() {
    var history = QueryHistory()
    for (time, query) in ["safari", "notes", "calc"].enumerated() { history.add(query, at: Double(time)) }
    #expect(history.older() == "calc")
    #expect(history.older() == "notes")
    #expect(history.older() == "safari")
    #expect(history.older() == nil)
    #expect(history.newer() == "notes")
    #expect(history.newer() == "calc")
    #expect(history.newer() == "")
    #expect(history.newer() == nil)
}

@Test func aQueryTypedAgainMovesToTheFrontOnce() {
    var history = QueryHistory()
    history.add("safari", at: 0)
    history.add("notes", at: 1)
    history.add(" safari ", at: 2)
    #expect(history.queries == ["safari", "notes"])
    history.add("   ", at: 3)
    #expect(history.queries == ["safari", "notes"])
}

@Test func typingEndsTheWalk() {
    var history = QueryHistory(queries: ["a", "b"])
    _ = history.older()
    _ = history.older()
    history.resetWalk()
    #expect(history.older() == "a")
}

@Test func historyKeepsAtMostItsLimit() {
    var history = QueryHistory()
    for index in 0..<(QueryHistory.limit + 10) { history.add("q\(index)", at: Double(index)) }
    #expect(history.queries.count == QueryHistory.limit)
    #expect(history.queries.first == "q\(QueryHistory.limit + 9)")
}

@Test func theLastQueryComesBackWithinFiveMinutes() {
    var history = QueryHistory()
    history.add("safari", at: 1000)
    #expect(history.restorable(at: 1000 + 60) == "safari")
    #expect(history.restorable(at: 1000 + QueryHistory.restoreWindow) == "safari")
    #expect(history.restorable(at: 1000 + QueryHistory.restoreWindow + 1) == nil)
    // A clock that went back (a restart) restores nothing.
    #expect(history.restorable(at: 10) == nil)
    history.clear()
    #expect(history.restorable(at: 1001) == nil)
}

@Test func oneModifierWithReturnPicksItsAlternative() {
    #expect(ReturnModifier.held(control: true, option: false, command: false) == .control)
    #expect(ReturnModifier.held(control: false, option: true, command: false) == .option)
    #expect(ReturnModifier.held(control: false, option: false, command: true) == .command)
    #expect(ReturnModifier.held(control: true, option: true, command: false) == nil)
    #expect(ReturnModifier.held(control: false, option: false, command: false) == nil)
}

@Test func modifierReturnRunsTheMappedSearch() {
    let google = WebSearch(id: "google", keyword: "g", title: "Search Google", url: "https://google.com/?q={query}")
    let gmail = WebSearch(id: "gmail", keyword: "gmail", title: "Open Gmail", url: "https://mail.google.com")
    let mapping = ["option": "google", "command": "gmail", "control": "removed"]
    #expect(ReturnModifier.option.search(in: mapping, from: [google, gmail])?.id == "google")
    // A bookmark without {query} cannot take the typed text, and a removed search is gone.
    #expect(ReturnModifier.command.search(in: mapping, from: [google, gmail]) == nil)
    #expect(ReturnModifier.control.search(in: mapping, from: [google, gmail]) == nil)
}
