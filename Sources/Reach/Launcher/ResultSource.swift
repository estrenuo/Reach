import ReachKit

/// A result with its text score (`Matcher` scale, about 200–1000). Sources that
/// have their own order, like recent files, give every result the same score.
struct Scored {
    var result: LaunchResult
    var score: Int
}

/// Something that answers a query: apps, files, and in later milestones the
/// calculator, web search keywords, system commands. The launcher asks every
/// source, ranks the openable results with Learning, and adds fallbacks when
/// none came back. A new kind of result is one new source.
protocol ResultSource: AnyObject {
    /// Results for `query` right away, or nil when they come later through
    /// `later` (Spotlight), which must not be called before this returns.
    /// Return [] for a query this source does not handle.
    /// Non-openable results (hints like "Type a file name") are shown first.
    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]?

    /// Drops a pending answer; called when the query changes or the launcher hides.
    func cancel()
}

extension ResultSource {
    func cancel() {}
}
