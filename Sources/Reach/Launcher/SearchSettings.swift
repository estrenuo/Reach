import Foundation
import ReachKit

/// Settings > Search (S-014): the file search keywords, the kinds they leave
/// out, the file types the default results add, and the search scope. Saved
/// in `Store.settings`.
@Observable
final class SearchSettings {
    static let shared = SearchSettings()
    private static let keywordsKey = "search.keywords"
    private static let hiddenKey = "search.hidden"
    private static let typesKey = "search.types"
    private static let scopeKey = "search.scope"

    var keywords: FileKeywords {
        didSet { save(try? JSONEncoder().encode(keywords), Self.keywordsKey) }
    }
    var hidden: Set<HiddenKind> {
        didSet { save(hidden.map(\.rawValue).sorted(), Self.hiddenKey) }
    }
    var types: Set<ResultType> {
        didSet { save(types.map(\.rawValue).sorted(), Self.typesKey) }
    }
    /// Folders, as full paths. Apps come from the folders' top level; files from anywhere inside.
    var scope: [String] {
        didSet { save(scope, Self.scopeKey) }
    }

    /// Where Reach looks until people change it: the app folders and the home folder.
    nonisolated static let standardScope = [
        "/Applications", "/Applications/Utilities",
        "/System/Applications", "/System/Applications/Utilities",
        "/System/Library/CoreServices/Applications",
        NSHomeDirectory() + "/Applications",
        NSHomeDirectory(),
    ]

    private init() {
        let defaults = Store.settings
        keywords = defaults.data(forKey: Self.keywordsKey)
            .flatMap { try? JSONDecoder().decode(FileKeywords.self, from: $0) } ?? FileKeywords()
        hidden = defaults.stringArray(forKey: Self.hiddenKey).map { Set($0.compactMap(HiddenKind.init(rawValue:))) }
            ?? HiddenKind.standard
        types = Set((defaults.stringArray(forKey: Self.typesKey) ?? []).compactMap(ResultType.init(rawValue:)))
        scope = defaults.stringArray(forKey: Self.scopeKey) ?? Self.standardScope
    }

    func queryKind(_ query: String, shellPrefix: String? = nil) -> QueryKind {
        QueryKind(query, keywords: keywords, shellPrefix: shellPrefix)
    }

    /// Puts every setting back as it was at first; the self-test leaves no trace this way.
    func reset() {
        keywords = FileKeywords()
        hidden = HiddenKind.standard
        types = []
        scope = Self.standardScope
    }

    private func save(_ value: Any?, _ key: String) {
        Store.settings.set(value, forKey: key)
    }
}
