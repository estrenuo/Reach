import ReachKit

/// The Reach Settings row (S-035): pinned above the other results, so
/// "settings" opens Reach's Settings even with the menu bar icon hidden.
final class SettingsSource: ResultSource {
    static let title = "Reach Settings"

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query, SettingsKeyword.matches(text) else { return [] }
        let row = LaunchResult(id: "reach:settings", title: Self.title, subtitle: "Open Settings (⌘,)",
                               icon: .symbol("gearshape"), url: nil, kindLabel: "Reach", isPinned: true,
                               opensSettings: true)
        return [Scored(result: row, score: 0)]
    }
}
