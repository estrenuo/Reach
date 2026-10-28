import AppKit
import ReachKit

/// Finds files and folders by name through Spotlight, most recently used first.
/// A new search keeps the previous results on screen until it finishes.
final class FileSearch: ResultSource {
    static let limit = 9
    private var query: NSMetadataQuery?
    private var observer: NSObjectProtocol?
    private var pending: (@MainActor ([LaunchResult]) -> Void)?

    static let hint = LaunchResult(id: "hint:files", title: "Type a file name", subtitle: "",
                                   icon: .symbol("doc.text.magnifyingglass"), url: nil)

    static func noMatch(_ name: String) -> LaunchResult {
        LaunchResult(id: "hint:nofiles", title: "No files match “\(name)”", subtitle: "",
                     icon: .symbol("doc.questionmark"), url: nil)
    }

    /// Files for `open <name>`, `'<name>` or ` <name>`, most recently used first.
    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .files(let name) = query else { return [] }
        guard !name.isEmpty else { return [Scored(result: Self.hint, score: 0)] }
        search(name) { found in
            later(found.isEmpty ? [Scored(result: Self.noMatch(name), score: 0)]
                                : found.map { Scored(result: $0, score: 0) })
        }
        return nil
    }

    /// Calls `done` once with up to nine results for `name`.
    func search(_ name: String, done: @escaping @MainActor ([LaunchResult]) -> Void) {
        cancel()
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUserHomeScope, "/Applications"]
        // Word starts through the Spotlight index ("rep" finds "Q3 report.pdf"). A
        // leading wildcard would skip the index and take several times as long.
        let escaped = name.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "*", with: "")
        query.predicate = NSPredicate(fromMetadataQueryString: "kMDItemFSName == \"\(escaped)*\"cdw")
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemLastUsedDateKey, ascending: false)]
        pending = done
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }
        self.query = query
        query.start()
    }

    private func finish() {
        guard let query, let done = pending else { return }
        query.disableUpdates()
        let count = min(query.resultCount, Self.limit)
        let results = (0..<count).compactMap { index in
            (query.result(at: index) as? NSMetadataItem).flatMap(Self.result)
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

    private static func result(_ item: NSMetadataItem) -> LaunchResult? {
        guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { return nil }
        let name = (item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String)
            ?? (path as NSString).lastPathComponent
        let kind = item.value(forAttribute: "kMDItemKind") as? String ?? "File"
        let folder = ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
        return LaunchResult(
            id: path, title: name, subtitle: (path as NSString).abbreviatingWithTildeInPath,
            icon: .file(path), url: URL(fileURLWithPath: path),
            kindLabel: "\(kind), in \((folder as NSString).lastPathComponent)")
    }
}
