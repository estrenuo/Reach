import AppKit
import ReachKit

extension SelfTest {
    /// S-018: the chosen fallbacks in their order, Always below the results,
    /// and the action panel for selected text following the same list.
    static func checkFallbacks(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let settings = WebSearchSettings.shared
        defer { settings.reset() }

        launcher.show()
        settings.fallbackIDs = ["wiki", "google"]
        lm.query = "zzqxv nothing"
        check("the fallbacks show in the chosen order", lm.results.map(\.id) == ["fallback:wiki", "fallback:google"],
              lm.results.map(\.id).joined(separator: ", "))

        let ddg = WebSearch(keyword: "ddg", title: "Search DuckDuckGo for “{query}”", url: "https://duckduckgo.com/?q={query}")
        settings.save(ddg)
        settings.fallbackIDs.insert(ddg.id, at: 0)
        lm.query = "zzqxv nothing "
        check("a custom search can be a fallback", lm.results.first?.title == "Search DuckDuckGo for “zzqxv nothing”")
        settings.remove(ddg.id)
        lm.query = "zzqxv nothing"
        check("a removed search drops out of the fallbacks", lm.results.first?.id == "fallback:wiki")

        lm.query = "safari"
        check("only when there are no results: none below Safari", !lm.results.contains { $0.id.hasPrefix("fallback:") })
        settings.fallbackMode = .always
        lm.query = "safari "
        check("always: the fallbacks come after the results", lm.results.first?.title == "Safari"
              && lm.results.suffix(2).map(\.id) == ["fallback:wiki", "fallback:google"] && lm.results.count <= LauncherModel.maxResults,
              lm.results.map(\.title).joined(separator: ", "))
        lm.query = "co"
        check("always: results and fallbacks share the nine rows", lm.results.count == LauncherModel.maxResults
              && lm.results.last?.id == "fallback:google")
        settings.fallbackMode = .noResults

        lm.showActions(for: .text("hello", source: "TextEdit"))
        let searches = lm.actions?.rows.map(\.title).filter { $0.hasPrefix("Search ") } ?? []
        check("selected text offers the same fallbacks", searches == ["Search Wikipedia for “hello”", "Search Google for “hello”"],
              searches.joined(separator: ", "))
        lm.closeActions()
        launcher.hide()
    }
}
