import Foundation
import Testing
@testable import ReachKit

struct ContactActionTests {
    let facetime = ContactAction(id: "ft", kind: .phone, title: "Call with FaceTime", url: "facetime://{query}", modifier: .option)

    @Test func actionHoldsKindTitleTemplateAndModifier() {
        #expect(facetime.kind == .phone && facetime.title == "Call with FaceTime")
        #expect(facetime.url == "facetime://{query}" && facetime.modifier == .option)
        #expect(ContactAction(kind: .email, title: "Copy", url: "x://{query}").modifier == nil)
    }

    @Test func phoneNumberDropsSpacesAndKeepsPlus() {
        let url = facetime.url(for: ContactField(.phone, value: " +31 (6) 1234-5678 "))
        #expect(url?.absoluteString == "facetime://%2B31612345678")
    }

    @Test func valueIsEncodedOnce() {
        let search = ContactAction(kind: .url, title: "Archive", url: "https://web.archive.org/web/{query}")
        let url = search.url(for: ContactField(.url, value: "example.com/a b?x=1&y=%20"))
        #expect(url?.absoluteString == "https://web.archive.org/web/example.com%2Fa%20b%3Fx%3D1%26y%3D%2520")
    }

    @Test func addressGoesOnOneLine() {
        let maps = ContactAction(kind: .address, title: "Google Maps", url: "https://www.google.com/maps/search/?api=1&query={query}")
        let url = maps.url(for: ContactField(.address, value: "Damrak 1\n1012 LG Amsterdam"))
        #expect(url?.absoluteString == "https://www.google.com/maps/search/?api=1&query=Damrak%201,%201012%20LG%20Amsterdam")
    }

    @Test func emailKeepsTheAt() {
        let gmail = ContactAction(kind: .email, title: "Gmail", url: "https://mail.google.com/mail/?view=cm&to={query}")
        #expect(gmail.url(for: ContactField(.email, value: "a.b+c@example.com"))?.absoluteString
            == "https://mail.google.com/mail/?view=cm&to=a.b%2Bc@example.com")
    }

    @Test func everyPlaceholderIsFilled() {
        let twice = ContactAction(kind: .phone, title: "Both", url: "x://{query}/{query}")
        #expect(twice.url(for: ContactField(.phone, value: "123"))?.absoluteString == "x://123/123")
    }

    @Test func otherKindOrEmptyValueMakesNoURL() {
        #expect(facetime.url(for: ContactField(.email, value: "a@example.com")) == nil)
        #expect(facetime.url(for: ContactField(.phone, value: " - ")) == nil)
    }

    @Test func problems() {
        func problem(_ title: String, _ url: String, _ modifier: ReturnModifier? = nil, kind: ContactField.Kind = .phone) -> String? {
            ContactAction.problem(ContactAction(kind: kind, title: title, url: url, modifier: modifier), others: [facetime])
        }
        #expect(problem(" ", "facetime://{query}") == "Give the action a title.")
        #expect(problem("Call", "facetime://") == "Put {query} in the URL where the detail goes.")
        #expect(problem("Call", "{query}") == "The URL needs a scheme, like facetime:")
        #expect(problem("Call", "tel:{query}", .option) == "⌥↩ already runs “Call with FaceTime” on phone numbers.")
        #expect(problem("Call", "tel:{query}", .control) == nil)
        #expect(problem("Mail", "x://{query}", .option, kind: .email) == nil)
        // Editing an action keeps its own modifier.
        #expect(ContactAction.problem(facetime, others: [facetime]) == nil)
    }

    @Test func findsTheActionForAModifier() {
        let all = [facetime, ContactAction(kind: .phone, title: "Call", url: "tel:{query}", modifier: .control)]
        #expect(ContactAction.action(in: all, for: .phone, modifier: .control)?.title == "Call")
        #expect(ContactAction.action(in: all, for: .email, modifier: .option) == nil)
    }

    @Test func savesAndLoads() throws {
        let data = try JSONEncoder().encode([facetime])
        #expect(try JSONDecoder().decode([ContactAction].self, from: data) == [facetime])
    }
}
