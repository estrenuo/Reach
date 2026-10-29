import ReachKit

/// The fallback web searches (S-018): the ones chosen in Settings > Search,
/// in their order. The launcher shows them for a query with no results, or
/// below every result list; the action panel offers them for selected text.
enum Fallbacks {
    static func results(for query: String, settings: WebSearchSettings = .shared) -> [LaunchResult] {
        guard !query.isEmpty else { return [] }
        return settings.fallbacks.compactMap { search in
            guard let url = WebSearchURL.make(template: search.url, query: query) else { return nil }
            return LaunchResult(
                id: "fallback:\(search.id)", title: search.title(for: query),
                subtitle: url.host() ?? "", icon: .symbol(search.symbol), url: url,
                kindLabel: "Web search")
        }
    }
}
