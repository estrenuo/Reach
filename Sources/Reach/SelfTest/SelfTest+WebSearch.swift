import AppKit
import ReachKit

extension SelfTest {
    /// S-016: keywords search a site, part of a keyword completes it, a keyword
    /// that is off falls through, and custom searches work and are saved.
    static func checkWebSearch(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let settings = WebSearchSettings.shared
        var opened: [URL] = []
        lm.opener = { opened.append($0); return true }
        defer { settings.reset() }

        launcher.show()
        lm.query = "wiki alfred"
        check("wiki and words: the Wikipedia search comes first",
              lm.results.first?.title == "Search Wikipedia for “alfred”", lm.results.map(\.title).joined(separator: ", "))
        lm.openSelected()
        check("↩ opens the search on the site", opened.last?.host() == "en.wikipedia.org"
              && opened.last?.absoluteString.hasSuffix("search=alfred") == true && !launcher.isVisible)

        launcher.show()
        lm.query = "wik"
        let partial = lm.results.firstIndex { $0.id == "web:wiki" }
        check("part of a keyword offers the search", partial.map { lm.results[$0].title } == "Search Wikipedia for “…”")
        if let partial { lm.open(at: partial) }
        check("↩ on it completes the keyword and keeps the launcher", lm.query == "wiki " && launcher.isVisible)
        check("the keyword and a space alone open the front page", lm.results.first?.url?.absoluteString == "https://en.wikipedia.org/")

        lm.query = "google alfred app"
        check("a keyword that is off falls through to the fallbacks",
              !lm.results.isEmpty && lm.results.allSatisfy { $0.id.hasPrefix("fallback:") })
        settings.set("google", on: true)
        lm.query = "google alfred app "
        check("switched on, it searches Google first", lm.results.first?.id == "web:google")

        let ddg = WebSearch(keyword: "ddg", title: "Search DuckDuckGo for “{query}”", url: "https://duckduckgo.com/?q={query}")
        settings.save(ddg)
        lm.query = "ddg mac apps"
        check("a custom search works under its keyword", lm.results.first?.title == "Search DuckDuckGo for “mac apps”"
              && lm.results.first?.url?.absoluteString == "https://duckduckgo.com/?q=mac%20apps")
        check("custom searches are saved in the test run's settings", Store.settings.data(forKey: "web.custom") != nil
              && Store.settings.stringArray(forKey: "web.on")?.contains("google") == true)
        settings.set(ddg.id, on: false)
        lm.query = "ddg mac apps "
        check("a custom search that is off falls through", lm.results.allSatisfy { $0.id.hasPrefix("fallback:") })
        settings.remove(ddg.id)
        check("Remove takes a custom search out", !settings.searches.contains { $0.id == ddg.id })
        launcher.hide()
    }
}
