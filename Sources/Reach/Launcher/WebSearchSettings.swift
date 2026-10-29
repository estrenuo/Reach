import Foundation
import ReachKit

/// Settings > Web Search (S-016): which built-in searches are on, and the
/// custom ones. Saved in `Store.settings`. Only what people change is saved,
/// so a built-in whose URL changes in a later version updates by itself.
@Observable
final class WebSearchSettings {
    static let shared = WebSearchSettings()
    private static let onKey = "web.on"
    private static let customKey = "web.custom"

    /// The page Settings > Web Search shows; not saved.
    enum Page: String, CaseIterable { case searches = "Searches", urls = "URLs" }
    var page = Page.searches

    // URLs (S-017)
    var recognizesURLs: Bool { didSet { Store.settings.set(recognizesURLs, forKey: "url.recognize") } }
    /// "https" or "http", for a domain typed without one.
    var scheme: String { didSet { Store.settings.set(scheme, forKey: "url.scheme") } }
    /// `mailto:a@b.c` and `spotify:track:1` count as URLs too.
    var withoutSlashes: Bool { didSet { Store.settings.set(withoutSlashes, forKey: "url.withoutSlashes") } }
    var keepsHistory: Bool { didSet { Store.settings.set(keepsHistory, forKey: "url.history") } }
    var retention: URLRetention { didSet { Store.settings.set(retention.rawValue, forKey: "url.retention") } }

    /// The ids of the built-ins that are on.
    private var on: Set<String> {
        didSet { Store.settings.set(on.sorted(), forKey: Self.onKey) }
    }
    private(set) var custom: [WebSearch] {
        didSet { Store.settings.set(try? JSONEncoder().encode(custom), forKey: Self.customKey) }
    }

    private init() {
        let defaults = Store.settings
        on = defaults.stringArray(forKey: Self.onKey).map(Set.init)
            ?? Set(WebSearches.builtIn.filter(\.isOn).map(\.id))
        custom = defaults.data(forKey: Self.customKey)
            .flatMap { try? JSONDecoder().decode([WebSearch].self, from: $0) } ?? []
        recognizesURLs = defaults.object(forKey: "url.recognize") as? Bool ?? true
        scheme = defaults.string(forKey: "url.scheme") ?? "https"
        withoutSlashes = defaults.bool(forKey: "url.withoutSlashes")
        keepsHistory = defaults.object(forKey: "url.history") as? Bool ?? true
        retention = defaults.string(forKey: "url.retention").flatMap(URLRetention.init(rawValue:)) ?? .month
    }

    /// The URL `query` names under the current settings, or nil.
    func typedURL(_ query: String) -> URL? {
        recognizesURLs ? TypedURL.url(from: query, scheme: scheme, withoutSlashes: withoutSlashes) : nil
    }

    /// Built-ins first, in Alfred's order, then custom searches in the order they were added.
    var searches: [WebSearch] {
        WebSearches.builtIn.map { search in
            var search = search
            search.isOn = on.contains(search.id)
            return search
        } + custom
    }

    func set(_ id: String, on isOn: Bool) {
        if let index = custom.firstIndex(where: { $0.id == id }) {
            custom[index].isOn = isOn
        } else if isOn {
            on.insert(id)
        } else {
            on.remove(id)
        }
    }

    /// Adds `search`, or replaces the custom search with its id.
    func save(_ search: WebSearch) {
        if let index = custom.firstIndex(where: { $0.id == search.id }) {
            custom[index] = search
        } else {
            custom.append(search)
        }
    }

    /// Only custom searches go; a built-in can be switched off.
    func remove(_ id: String) {
        custom.removeAll { $0.id == id }
    }

    /// Keywords other features own, so a custom search cannot take them.
    var taken: [String: String] {
        let keywords = SearchSettings.shared.keywords
        return Dictionary(FileMode.allCases.map { (keywords[$0].word.lowercased(), $0.title) },
                          uniquingKeysWith: { first, _ in first })
    }

    /// Back to the searches Reach starts with; the self-test leaves no trace this way.
    func reset() {
        on = Set(WebSearches.builtIn.filter(\.isOn).map(\.id))
        custom = []
        recognizesURLs = true
        scheme = "https"
        withoutSlashes = false
        keepsHistory = true
        retention = .month
    }
}
