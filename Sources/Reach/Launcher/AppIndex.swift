import AppKit
import ReachKit

/// The apps in the search scope, read from disk in the background.
@Observable
final class AppIndex {
    struct Entry: Sendable {
        var name: String
        var path: String
    }

    nonisolated static let scope = [
        "/Applications", "/Applications/Utilities",
        "/System/Applications", "/System/Applications/Utilities",
        "/System/Library/CoreServices/Applications",
        NSHomeDirectory() + "/Applications",
    ]

    private(set) var entries: [Entry] = []
    private var lastScan = Date.distantPast

    /// Rescans when the list is older than a minute, so new apps show up.
    func refreshIfStale() {
        guard Date.now.timeIntervalSince(lastScan) > 60 else { return }
        lastScan = .now
        Task {
            let found = await Task.detached(priority: .userInitiated) { Self.scan() }.value
            entries = found
        }
    }

    /// Scans now and waits; used by the self-test and snapshots.
    func refreshNow() async {
        lastScan = .now
        entries = await Task.detached(priority: .userInitiated) { Self.scan() }.value
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

    nonisolated private static func scan() -> [Entry] {
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
