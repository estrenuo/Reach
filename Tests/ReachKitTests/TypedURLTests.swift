import Foundation
import Testing
@testable import ReachKit

private func typed(_ query: String, scheme: String = "https", withoutSlashes: Bool = false) -> String? {
    TypedURL.url(from: query, scheme: scheme, withoutSlashes: withoutSlashes)?.absoluteString
}

@Test("A bare domain gets the default scheme")
func typedURLBareDomain() {
    #expect(typed("example.com") == "https://example.com")
    #expect(typed("google.co.uk") == "https://google.co.uk")
    #expect(typed("mijn.nn.nl/inloggen?x=1") == "https://mijn.nn.nl/inloggen?x=1")
    #expect(typed("example.com", scheme: "http") == "http://example.com")
    #expect(typed("Claude.AI") == "https://Claude.AI")
    #expect(typed("localhost:3000") == "https://localhost:3000")
    #expect(typed("192.168.1.1") == "https://192.168.1.1")
    #expect(typed("example.com:8080/x") == "https://example.com:8080/x")
}

@Test("A URL with a scheme is taken as typed")
func typedURLWithScheme() {
    #expect(typed("http://example.com/a") == "http://example.com/a")
    #expect(typed("https://claude.ai") == "https://claude.ai")
    #expect(typed("ftp://files.example.org") == "ftp://files.example.org")
    #expect(typed("https://") == nil)
    #expect(typed("://example.com") == nil)
}

@Test("File names, sums, mail addresses and words are not URLs")
func typedURLNotAURL() {
    #expect(typed("report.pdf") == nil)
    #expect(typed("README.md") == nil)
    #expect(typed("build.sh") == nil)
    #expect(typed("main.rs") == nil)
    #expect(typed("2.5*2") == nil)
    #expect(typed("1.2") == nil)
    #expect(typed("999.1.1.1") == nil)
    #expect(typed("sander@example.com") == nil)
    #expect(typed("safari") == nil)
    #expect(typed("example .com") == nil)
    #expect(typed("-bad.com") == nil)
    #expect(typed("example..com") == nil)
    #expect(typed("example.com:abc") == nil)
    #expect(typed("") == nil)
}

@Test("A scheme without // is a URL only with the setting on")
func typedURLWithoutSlashes() {
    #expect(typed("mailto:sander@example.com") == nil)
    #expect(typed("mailto:sander@example.com", withoutSlashes: true) == "mailto:sander@example.com")
    #expect(typed("spotify:track:123", withoutSlashes: true) == "spotify:track:123")
    #expect(typed("note:", withoutSlashes: true) == nil)
}

@Test("The history row shows the URL without https:// and a lone trailing slash")
func typedURLDisplay() {
    #expect(TypedURL.display("https://claude.ai/") == "claude.ai")
    #expect(TypedURL.display("http://example.com/a/") == "example.com/a/")
    #expect(TypedURL.display("ftp://files.example.org") == "ftp://files.example.org")
}

@Test("History entries expire after the chosen period, or never")
func urlRetention() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29))!
    func ago(days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: now)! }
    #expect(!URLRetention.week.isExpired(lastUsed: ago(days: 6), now: now, calendar: calendar))
    #expect(URLRetention.week.isExpired(lastUsed: ago(days: 8), now: now, calendar: calendar))
    #expect(!URLRetention.month.isExpired(lastUsed: ago(days: 29), now: now, calendar: calendar))
    #expect(URLRetention.month.isExpired(lastUsed: ago(days: 31), now: now, calendar: calendar))
    #expect(!URLRetention.threeMonths.isExpired(lastUsed: ago(days: 85), now: now, calendar: calendar))
    #expect(URLRetention.threeMonths.isExpired(lastUsed: ago(days: 95), now: now, calendar: calendar))
    #expect(URLRetention.year.isExpired(lastUsed: ago(days: 370), now: now, calendar: calendar))
    #expect(!URLRetention.never.isExpired(lastUsed: ago(days: 5000), now: now, calendar: calendar))
}
