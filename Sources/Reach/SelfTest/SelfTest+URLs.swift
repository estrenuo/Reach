import AppKit
import ReachKit

extension SelfTest {
    /// S-017: typed URLs open, opened URLs come back from the history, and the
    /// settings change what counts. The history lives in the test run's store.
    static func checkURLs(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let settings = WebSearchSettings.shared
        let history = lm.history
        var opened: [URL] = []
        lm.opener = { opened.append($0); return true }
        history.clear()
        defer {
            settings.reset()
            history.now = { .now }
            history.clear()
        }

        launcher.show()
        lm.query = "example.org/docs"
        check("a typed domain is the first result, with https", lm.results.first?.url?.absoluteString == "https://example.org/docs"
              && lm.selection == 0, lm.results.map(\.title).joined(separator: ", "))
        lm.openSelected()
        check("↩ opens it and the history remembers it", opened.last?.absoluteString == "https://example.org/docs"
              && history.entries.map(\.url) == ["https://example.org/docs"])

        launcher.show()
        lm.query = "docs"
        check("part of a URL finds it in the history", lm.results.contains { $0.id == "history:https://example.org/docs" },
              lm.results.map(\.title).joined(separator: ", "))
        lm.query = "example.org/docs"
        check("the typed URL is not listed twice", lm.results.filter { $0.url?.absoluteString == "https://example.org/docs" }.count == 1)

        lm.query = "report.pdf"
        check("a file name is not a URL", !lm.results.contains { $0.id == "url:typed" })
        settings.scheme = "http"
        lm.query = "example.net"
        check("the scheme setting is used", lm.results.first?.url?.absoluteString == "http://example.net")
        lm.query = "mailto:test@example.com"
        check("a scheme without // is a search at first", !lm.results.contains { $0.id == "url:typed" })
        settings.withoutSlashes = true
        lm.query = "mailto:test@example.com "
        check("with the setting on, it is a URL", lm.results.first?.url?.absoluteString == "mailto:test@example.com")
        settings.recognizesURLs = false
        lm.query = "example.net "
        check("Recognize URLs off makes a domain a search", !lm.results.contains { $0.id == "url:typed" })
        settings.recognizesURLs = true

        settings.keepsHistory = false
        lm.query = "example.com"
        lm.openSelected()
        check("with the history off, nothing is remembered", history.entries.count == 1)
        settings.keepsHistory = true

        // Five weeks on, a month's retention lets the URL go; Never keeps it.
        let later = Date.now.addingTimeInterval(35 * 86_400)
        history.now = { later }
        settings.retention = .never
        history.prune()
        check("Never keeps an old URL", history.entries.count == 1)
        settings.retention = .month
        history.prune()
        check("a URL not used for the chosen period goes", history.entries.isEmpty)
        launcher.hide()
    }
}
