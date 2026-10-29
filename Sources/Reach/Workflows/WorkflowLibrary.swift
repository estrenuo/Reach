import Foundation
import ReachKit

/// The installed workflows (S-041): one folder each, in the sync folder's
/// Workflows folder when Reach syncs (S-039), else in Application Support.
/// Test runs use a Workflows folder next to their /tmp store.
@Observable
final class WorkflowLibrary {
    static let shared = WorkflowLibrary()

    private(set) var workflows: [Workflow] = []
    /// When the folder was last read; it is read again when the launcher shows.
    @ObservationIgnored private var readAt = Date.distantPast

    private init() {
        reload()
    }

    /// The folder this Mac reads workflows from now.
    var folder: URL {
        if let sync = SyncService.shared.sync { return sync.workflows }
        return Self.home.appending(path: "Workflows", directoryHint: .isDirectory)
    }

    /// Where workflows keep their own files (`alfred_workflow_data` and `_cache`).
    var dataFolder: URL { Self.home.appending(path: "Workflow Data", directoryHint: .isDirectory) }
    var cacheFolder: URL {
        Store.isOverridden ? Self.home.appending(path: "Workflow Cache", directoryHint: .isDirectory)
            : URL.cachesDirectory.appending(path: "Reach/Workflow Data", directoryHint: .isDirectory)
    }

    /// Application Support/Reach, or the folder of the test store.
    private static var home: URL { Store.url.deletingLastPathComponent() }

    func reload() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let folders = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey],
                                                                    options: .skipsHiddenFiles)) ?? []
        workflows = folders.compactMap(Workflow.init(folder:))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        readAt = .now
    }

    /// Reads the folder again when it was read more than two seconds ago,
    /// so a workflow copied in shows up the next time the launcher opens.
    func reloadIfStale() {
        if Date.now.timeIntervalSince(readAt) > 2 { reload() }
    }

    func workflow(_ id: String) -> Workflow? { workflows.first { $0.id == id } }

    /// The environment for a script of `workflow`.
    func environment(for workflow: Workflow, variables: [String: String] = [:]) -> [String: String] {
        workflow.environment(data: dataFolder, cache: cacheFolder, extra: variables)
    }
}
