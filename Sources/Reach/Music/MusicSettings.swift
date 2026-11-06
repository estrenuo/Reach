import Foundation
import Observation
import ReachKit

/// Settings > Music: the mini player (S-060) on General, and the music
/// keywords (S-059) on Keywords. Saved in `Store.settings`.
@Observable
final class MusicSettings {
    static let shared = MusicSettings()
    private static let keywordsKey = "music.keywords"
    private static let defaultResultsKey = "music.defaultResults"
    private static let miniKeywordKey = "music.miniPlayer.keyword"
    private static let randomKey = "music.randomMinimum"
    private static let hidesKey = "music.hidesAfterChoosing"
    private static let includeKey = "music.include."
    static let randomRange = 1...50

    enum Page: String, CaseIterable {
        case general = "General", keywords = "Keywords"
    }

    /// The page on screen; not saved.
    var page = Page.general
    var keywords: [MusicKeyword] {
        didSet { Store.settings.set(try? JSONEncoder().encode(keywords), forKey: Self.keywordsKey) }
    }
    /// Part of a keyword or title ("nex") finds a music command too, not only the whole keyword.
    var showsInDefaultResults: Bool {
        didSet { Store.settings.set(showsInDefaultResults, forKey: Self.defaultResultsKey) }
    }
    /// The word that opens the mini player, `music` at first.
    var miniPlayerKeyword: String {
        didSet { Store.settings.set(miniPlayerKeyword, forKey: Self.miniKeywordKey) }
    }
    /// Random Album skips albums with fewer songs than this.
    var randomMinimum: Int {
        didSet { Store.settings.set(randomMinimum, forKey: Self.randomKey) }
    }
    /// The launcher hides after Return plays something from the mini player.
    var hidesAfterChoosing: Bool {
        didSet { Store.settings.set(hidesAfterChoosing, forKey: Self.hidesKey) }
    }
    var include: MusicLibrary.Include {
        didSet {
            Store.settings.set(include.podcasts, forKey: Self.includeKey + "podcasts")
            Store.settings.set(include.videos, forKey: Self.includeKey + "videos")
            Store.settings.set(include.untagged, forKey: Self.includeKey + "untagged")
        }
    }

    private init() {
        let defaults = Store.settings
        let saved = defaults.data(forKey: Self.keywordsKey)
            .flatMap { try? JSONDecoder().decode([MusicKeyword].self, from: $0) } ?? []
        keywords = MusicKeyword.complete(saved)
        showsInDefaultResults = defaults.object(forKey: Self.defaultResultsKey) as? Bool ?? true
        miniPlayerKeyword = defaults.string(forKey: Self.miniKeywordKey) ?? "music"
        let minimum = defaults.object(forKey: Self.randomKey) as? Int ?? 5
        randomMinimum = min(max(minimum, Self.randomRange.lowerBound), Self.randomRange.upperBound)
        hidesAfterChoosing = defaults.object(forKey: Self.hidesKey) as? Bool ?? true
        include = MusicLibrary.Include(podcasts: defaults.bool(forKey: Self.includeKey + "podcasts"),
                                       videos: defaults.bool(forKey: Self.includeKey + "videos"),
                                       untagged: defaults.bool(forKey: Self.includeKey + "untagged"))
    }

    subscript(command: MusicCommand) -> MusicKeyword {
        get { keywords.first { $0.command == command } ?? MusicKeyword(command: command) }
        set {
            guard let index = keywords.firstIndex(where: { $0.command == command }) else { return }
            keywords[index] = newValue
        }
    }

    /// The music keywords in use, for checking a new keyword against them.
    var taken: [String: String] {
        var taken = Dictionary(keywords.filter(\.isOn).map { ($0.keyword.lowercased(), $0.command.title) },
                               uniquingKeysWith: { first, _ in first })
        taken[miniPlayerKeyword.lowercased()] = "the mini player"
        return taken
    }

    /// Back to what Reach starts with; the self-test leaves no trace this way.
    func reset() {
        page = .general
        keywords = MusicKeyword.defaults
        showsInDefaultResults = true
        miniPlayerKeyword = "music"
        randomMinimum = 5
        hidesAfterChoosing = true
        include = MusicLibrary.Include()
    }
}
