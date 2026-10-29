import Foundation
import ReachKit

/// Settings > Advanced (S-038): the typed-query history and the searches
/// ⌃↩, ⌥↩ and ⌘↩ run, saved in `Store.settings`.
@Observable
final class AdvancedOptions {
    static let shared = AdvancedOptions()

    /// ⌃↑/⌃↓ walk the queries typed before.
    var remembersQueries: Bool { didSet { Store.settings.set(remembersQueries, forKey: "advanced.history") } }
    /// The launcher opens with the last query when it was typed less than 5 minutes ago.
    var restoresLastQuery: Bool { didSet { Store.settings.set(restoresLastQuery, forKey: "advanced.restore") } }
    /// Web search id per `ReturnModifier` raw value.
    var alternatives: [String: String] { didSet { Store.settings.set(alternatives, forKey: "advanced.alternatives") } }

    private init() {
        let saved = Store.settings
        remembersQueries = saved.object(forKey: "advanced.history") as? Bool ?? true
        restoresLastQuery = saved.bool(forKey: "advanced.restore")
        alternatives = saved.dictionary(forKey: "advanced.alternatives") as? [String: String] ?? [:]
    }

    func reset() {
        remembersQueries = true
        restoresLastQuery = false
        alternatives = [:]
    }
}
