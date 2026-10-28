import ReachKit

/// Web searches offered when the query has no results. M3 makes these editable.
enum Fallbacks {
    struct Engine {
        var name: String
        var template: String
        var symbol: String
    }

    static let engines = [
        Engine(name: "Google", template: "https://www.google.com/search?q={query}", symbol: "magnifyingglass"),
        Engine(name: "Amazon", template: "https://www.amazon.com/s?k={query}", symbol: "cart"),
        Engine(name: "Wikipedia", template: "https://en.wikipedia.org/wiki/Special:Search?search={query}", symbol: "book"),
    ]

    static func results(for query: String) -> [LaunchResult] {
        engines.compactMap { engine in
            guard let url = WebSearchURL.make(template: engine.template, query: query) else { return nil }
            return LaunchResult(
                id: "fallback:\(engine.name)", title: "Search \(engine.name) for “\(query)”",
                subtitle: url.host() ?? "", icon: .symbol(engine.symbol), url: url,
                kindLabel: "Web search, \(engine.name)")
        }
    }
}
