import AppKit
import ReachKit

/// The apps in the search scope, read from disk in the background.
@Observable
final class AppIndex: ResultSource {
    struct Entry: Sendable {
        var name: String
        var path: String
    }

    /// The search scope (Settings > Search); apps come from each folder's top level.
    @ObservationIgnored var scope: () -> [String] = { SearchSettings.shared.scope }

    private(set) var entries: [Entry] = []
    private var lastScan = Date.distantPast
    private var scanned: [String] = []

    /// Rescans when the list is older than a minute, so new apps show up,
    /// or when the scope changed in Settings.
    func refreshIfStale() {
        let folders = scope()
        guard Date.now.timeIntervalSince(lastScan) > 60 || folders != scanned else { return }
        lastScan = .now
        scanned = folders
        Task {
            let found = await Task.detached(priority: .userInitiated) { Self.scan(folders) }.value
            entries = found
        }
    }

    /// Scans now and waits; used by the self-test and snapshots.
    func refreshNow() async {
        lastScan = .now
        let folders = scope()
        scanned = folders
        entries = await Task.detached(priority: .userInitiated) { Self.scan(folders) }.value
    }

    /// Apps for a normal query, sorted by name so equal scores stay alphabetical.
    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query else { return [] }
        return results(for: text)
            .sorted { $0.0.title.localizedStandardCompare($1.0.title) == .orderedAscending }
            .map { Scored(result: $0.0, score: $0.1) }
    }

    func results(for query: String) -> [(LaunchResult, Int)] {
        entries.compactMap { entry in
            guard let score = Matcher.score(query: query, title: entry.name) else { return nil }
            let result = LaunchResult(
                id: entry.path, title: entry.name, subtitle: entry.path,
                icon: .file(entry.path), url: URL(fileURLWithPath: entry.path), kindLabel: "Application")
            return (result, score)
        }
    }

    nonisolated private static func scan(_ scope: [String]) -> [Entry] {
        let files = FileManager.default
        var seen = Set<String>()
        var found: [Entry] = []
        for folder in scope {
            guard let names = try? files.contentsOfDirectory(atPath: folder) else { continue }
            for name in names where name.hasSuffix(".app") {
                let path = (folder as NSString).appendingPathComponent(name)
                let resolved = (path as NSString).resolvingSymlinksInPath
                guard seen.insert(resolved).inserted else { continue }
                // The localized name, like "Contacten" for Contacts.app.
                let display = (files.displayName(atPath: path) as NSString).deletingPathExtension
                found.append(Entry(name: display, path: path))
            }
        }
        return found
    }
}
