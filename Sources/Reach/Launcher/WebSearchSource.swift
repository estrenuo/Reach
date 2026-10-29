import ReachKit

/// Web searches by keyword (S-016): `wiki alfred` searches Wikipedia, and
/// part of a keyword offers the search among the apps.
final class WebSearchSource: ResultSource {
    let settings: WebSearchSettings
    /// The query as typed. `QueryKind` trims it, and "wiki " with its space
    /// means the keyword is done; the model sets this before asking.
    var typed = ""

    init(settings: WebSearchSettings = .shared) {
        self.settings = settings
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal = query else { return [] }
        return WebSearches.matches(typed, in: settings.searches).compactMap { match in
            let url = match.url
            guard url != nil || match.completion != nil else { return nil }
            let result = LaunchResult(id: "web:\(match.search.id)", title: match.title,
                                      subtitle: url?.host() ?? "Press ↩ to type the words to search for",
                                      icon: .symbol(match.search.symbol), url: url,
                                      kindLabel: "Web search", completes: match.completion)
            return Scored(result: result, score: match.score)
        }
    }
}
