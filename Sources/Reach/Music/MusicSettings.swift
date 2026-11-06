import Foundation
import Observation
import ReachKit

/// Settings > Music (S-059): the music keywords, each on or off, and
/// whether they also show among the other results. Saved in `Store.settings`.
@Observable
final class MusicSettings {
    static let shared = MusicSettings()
    private static let keywordsKey = "music.keywords"
    private static let defaultResultsKey = "music.defaultResults"

    var keywords: [MusicKeyword] {
        didSet { Store.settings.set(try? JSONEncoder().encode(keywords), forKey: Self.keywordsKey) }
    }
    /// Part of a keyword or title ("nex") finds a music command too, not only the whole keyword.
    var showsInDefaultResults: Bool {
        didSet { Store.settings.set(showsInDefaultResults, forKey: Self.defaultResultsKey) }
    }

    private init() {
        let defaults = Store.settings
        let saved = defaults.data(forKey: Self.keywordsKey)
            .flatMap { try? JSONDecoder().decode([MusicKeyword].self, from: $0) } ?? []
        keywords = MusicKeyword.complete(saved)
        showsInDefaultResults = defaults.object(forKey: Self.defaultResultsKey) as? Bool ?? true
    }

    subscript(command: MusicCommand) -> MusicKeyword {
        get { keywords.first { $0.command == command } ?? MusicKeyword(command: command) }
        set {
            guard let index = keywords.firstIndex(where: { $0.command == command }) else { return }
            keywords[index] = newValue
        }
    }

    /// Back to the keywords Reach starts with; the self-test leaves no trace this way.
    func reset() {
        keywords = MusicKeyword.defaults
        showsInDefaultResults = true
    }
}
