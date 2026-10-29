import ReachKit

/// Web searches offered when the query has no results: Google, Amazon and
/// Wikipedia from the built-in web searches, whether their keyword is on or
/// not. S-018 makes the list editable.
enum Fallbacks {
    /// Built-in ids, with the site name VoiceOver reads.
    static let names = [("google", "Google"), ("amazon", "Amazon"), ("wiki", "Wikipedia")]

    static var engines: [(WebSearch, String)] {
        names.compactMap { id, name in WebSearches.builtIn.first { $0.id == id }.map { ($0, name) } }
    }

    static func results(for query: String) -> [LaunchResult] {
        guard !query.isEmpty else { return [] }
        return engines.compactMap { engine, name in
            guard let url = WebSearchURL.make(template: engine.url, query: query) else { return nil }
            return LaunchResult(
                id: "fallback:\(name)", title: engine.title(for: query),
                subtitle: url.host() ?? "", icon: .symbol(engine.symbol), url: url,
                kindLabel: "Web search, \(name)")
        }
    }
}
