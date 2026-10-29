import AppKit
import ReachKit

/// Finds files and folders through Spotlight, most recently used first: by
/// name for `open` and `find`, by contents for `in`, by Finder tag for `tags`,
/// and the ticked Default Results types for a query without a keyword (S-014).
/// A new search keeps the previous results on screen until it finishes.
final class FileSearch: ResultSource {
    static let limit = 9
    private var query: NSMetadataQuery?
    private var observer: NSObjectProtocol?
    private var pending: (@MainActor ([LaunchResult]) -> Void)?
    let settings: SearchSettings

    init(settings: SearchSettings = .shared) {
        self.settings = settings
    }

    /// The row for a keyword with no text after it yet.
    static func hint(_ mode: FileMode) -> LaunchResult {
        let title = switch mode {
        case .open, .reveal: "Type a file name"
        case .inside: "Type words from inside a file"
        case .tags: "Type a tag"
        }
        return LaunchResult(id: "hint:files", title: title, subtitle: "",
                            icon: .symbol("doc.text.magnifyingglass"), url: nil)
    }

    static func noMatch(_ query: FileQuery) -> LaunchResult {
        let title = switch query.mode {
        case .open, .reveal: "No files match “\(query.text)”"
        case .inside: "No files contain “\(query.text)”"
        case .tags: "No files are tagged “\(query.text)”"
        }
        return LaunchResult(id: "hint:nofiles", title: title, subtitle: "",
                            icon: .symbol("doc.questionmark"), url: nil)
    }

    func results(for kind: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        switch kind {
        case .files(let query):
            guard !query.text.isEmpty else { return [Scored(result: Self.hint(query.mode), score: 0)] }
            search(SpotlightPredicate.string(for: query, hiding: settings.hidden), reveals: query.reveals) { found in
                later(found.isEmpty ? [Scored(result: Self.noMatch(query), score: 0)]
                                    : found.map { Scored(result: $0, score: 0) })
            }
            return nil
        case .normal(let text):
            guard let predicate = SpotlightPredicate.defaultResults(name: text, types: settings.types) else { return [] }
            search(predicate, reveals: false) { found in
                // Below an app with the same match, so apps still lead.
                later(found.map { Scored(result: $0, score: (Matcher.score(query: text, title: $0.title) ?? 200) - 100) })
            }
            return nil
        case .empty, .path:
            return []
        }
    }

    /// Calls `done` once with up to nine results for a Spotlight query string.
    func search(_ predicate: String, reveals: Bool, done: @escaping @MainActor ([LaunchResult]) -> Void) {
        cancel()
        let query = NSMetadataQuery()
        query.searchScopes = settings.scope
        query.predicate = NSPredicate(fromMetadataQueryString: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemLastUsedDateKey, ascending: false)]
        pending = done
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish(reveals: reveals) }
        }
        self.query = query
        query.start()
    }

    private func finish(reveals: Bool) {
        guard let query, let done = pending else { return }
        query.disableUpdates()
        let count = min(query.resultCount, Self.limit)
        let results = (0..<count).compactMap { index in
            (query.result(at: index) as? NSMetadataItem).flatMap { Self.result($0, reveals: reveals) }
        }
        cancel()
        done(results)
    }

    func cancel() {
        query?.stop()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        query = nil
        observer = nil
        pending = nil
    }

    private static func result(_ item: NSMetadataItem, reveals: Bool) -> LaunchResult? {
        guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { return nil }
        let name = (item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String)
            ?? (path as NSString).lastPathComponent
        let kind = item.value(forAttribute: "kMDItemKind") as? String ?? "File"
        let folder = ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
        let types = item.value(forAttribute: "kMDItemContentTypeTree") as? [String] ?? []
        return LaunchResult(
            id: path, title: name, subtitle: (path as NSString).abbreviatingWithTildeInPath,
            icon: .file(path), url: URL(fileURLWithPath: path),
            kindLabel: "\(kind), in \((folder as NSString).lastPathComponent)",
            isFolder: types.contains("public.folder"), reveals: reveals)
    }
}
