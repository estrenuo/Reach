import Foundation
import ReachKit

/// A source with fixed titles and optional delay, so launcher checks do not
/// depend on the apps on this Mac and slow sources can be tested.
final class FakeSource: ResultSource {
    private let titles: [String]
    private let delay: Duration?

    init(_ titles: [String], delay: Duration? = nil) {
        self.titles = titles
        self.delay = delay
    }

    static func url(_ title: String) -> URL {
        URL(string: "reach-test://app/\(title.replacingOccurrences(of: " ", with: "-"))")!
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query else { return [] }
        let found = titles.compactMap { title in
            Matcher.score(query: text, title: title).map {
                Scored(result: LaunchResult(id: "fake:\(title)", title: title, subtitle: "Test app",
                                            icon: .symbol("app"), url: Self.url(title)), score: $0)
            }
        }
        guard let delay else { return found }
        Task {
            try? await Task.sleep(for: delay)
            later(found)
        }
        return nil
    }
}
