import Foundation
import ReachKit

/// The installed workflows (S-041): one folder each, in the sync folder's
/// Workflows folder when Reach syncs (S-039), else in Application Support.
/// Test runs use a Workflows folder next to their /tmp store.
@Observable
final class WorkflowLibrary {
    static let shared = WorkflowLibrary()
    static let windowID = "workflows"

    private(set) var workflows: [Workflow] = []
    /// The workflow the Workflows window shows (S-042); nil shows the start cards.
    var selection: String?
    /// The text in Filter Workflows.
    var filter = ""
    /// What went wrong with the last install or change, shown in the window.
    var failure: String?
    /// Counts Filter Workflows (⇧⌘F), which focuses the filter field.
    var filterRequests = 0
    /// The workflow waiting for Remove's confirmation.
    var removing: Workflow?
    /// The workflow in the Configure Workflow… sheet (S-043).
    var configuring: Workflow?
    /// The workflow in the Workflow Info… sheet (S-046).
    var editingInfo: Workflow?
    /// The tab Workflow Info… opens on.
    var infoTab = WorkflowInfoSheet.Tab.about
    /// The debugger's log of script runs (S-045), and whether its panel shows.
    var log = WorkflowLog()
    var logLevel = WorkflowLogLevel.all
    var debugging = false
    /// The workflow in the Hotkeys… sheet (S-049).
    var editingHotkeys: Workflow?
    /// Called after every read of the folder, so workflow hotkeys follow it.
    @ObservationIgnored var onReload: () -> Void = {}
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
        onReload()
    }

    /// Reads the folder again when it was read more than two seconds ago,
    /// so a workflow copied in shows up the next time the launcher opens.
    func reloadIfStale() {
        if Date.now.timeIntervalSince(readAt) > 2 { reload() }
    }

    func workflow(_ id: String) -> Workflow? { workflows.first { $0.id == id } }

    /// The workflows that match Filter Workflows.
    var shown: [Workflow] { workflows.filter { WorkflowFolder.matches($0, filter: filter) } }

    var selected: Workflow? { selection.flatMap(workflow) }

    /// Copies a workflow folder, or unpacks an .alfredworkflow file, into the folder, and selects it.
    func install(from source: URL) {
        failure = nil
        do {
            let installed: URL
            if source.pathExtension == "alfredworkflow" {
                installed = try unpack(source)
            } else {
                installed = try WorkflowFolder.install(from: source, into: folder)
            }
            reload()
            selection = installed.lastPathComponent
        } catch WorkflowFolder.Failure.notAWorkflow {
            failure = "“\(source.lastPathComponent)” is not a workflow: it has no info.plist."
        } catch {
            failure = "Unable to install “\(source.lastPathComponent)”: \(error.localizedDescription)"
        }
    }

    /// Adds the Hello World example and selects it.
    func addExample() {
        failure = nil
        do {
            let added = try WorkflowFolder.addExample(into: folder)
            reload()
            selection = added.lastPathComponent
        } catch {
            failure = "Unable to add the example: \(error.localizedDescription)"
        }
    }

    func setEnabled(_ enabled: Bool, _ workflow: Workflow) {
        do {
            try WorkflowFolder.setDisabled(!enabled, folder: workflow.folder)
        } catch {
            failure = "Unable to change “\(workflow.name)”: \(error.localizedDescription)"
        }
        reload()
    }

    /// Keeps the Configure Workflow… values in the folder's prefs.plist.
    func saveConfiguration(_ values: [String: String], for workflow: Workflow) {
        do {
            try WorkflowConfiguration.save(values, settings: workflow.settings, in: workflow.folder)
        } catch {
            failure = "Unable to save the configuration of “\(workflow.name)”: \(error.localizedDescription)"
        }
        reload()
    }

    /// Saves Workflow Info…: About, README and variables go into info.plist.
    func saveInfo(_ info: WorkflowInfo, for workflow: Workflow) {
        do {
            try WorkflowFolder.update(workflow.folder) { info.apply(to: &$0) }
        } catch {
            failure = "Unable to save “\(workflow.name)”: \(error.localizedDescription)"
        }
        reload()
    }

    /// Writes an .alfredworkflow file to share: Don't Export values blanked,
    /// Configure Workflow… values left out.
    func export(_ workflow: Workflow, to file: URL) {
        let staging = FileManager.default.temporaryDirectory.appending(path: "Reach-export-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: staging) }
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            let staged = try WorkflowExport.stage(workflow.folder, in: staging)
            try? FileManager.default.removeItem(at: file)
            let zip = Process()
            zip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            zip.arguments = ["-c", "-k", "--norsrc", staged.path, file.path]
            try zip.run()
            zip.waitUntilExit()
            if zip.terminationStatus != 0 { failure = "Unable to export “\(workflow.name)”." }
        } catch {
            failure = "Unable to export “\(workflow.name)”: \(error.localizedDescription)"
        }
    }

    /// Moves the workflow's folder to the Trash. The self-test swaps `trash`.
    func remove(_ workflow: Workflow) {
        do {
            try WorkflowFolder.remove(workflow.folder, trash: trash)
            if selection == workflow.id { selection = nil }
        } catch {
            failure = "Unable to move “\(workflow.name)” to the Trash: \(error.localizedDescription)"
        }
        reload()
    }

    @ObservationIgnored var trash: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }

    /// An .alfredworkflow file is a zip of the folder's contents.
    private func unpack(_ file: URL) throws -> URL {
        let target = folder.appending(path: WorkflowFolder.newName(), directoryHint: .isDirectory)
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", file.path, target.path]
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0, Workflow(folder: target) != nil else {
            try? FileManager.default.removeItem(at: target)
            throw WorkflowFolder.Failure.notAWorkflow
        }
        return target
    }

    /// Logs a script run for the debugger.
    func record(_ workflow: Workflow, object: String, input: String?, result: ScriptResult) {
        log.record(workflow: workflow.name, object: object, input: input, output: result.text, errors: result.errors,
                   status: result.status, failure: result.failure)
    }

    /// Logs an object Reach does not run, so the debugger says why nothing happened.
    func skipped(_ workflow: Workflow, kind: String) {
        log.skipped(workflow: workflow.name, kind: kind)
    }

    /// The selected workflow's log lines at the chosen level, as text for Copy.
    var selectedLogText: String {
        guard let name = selected?.name else { return "" }
        return WorkflowLog.text(log.shown(logLevel).filter { $0.workflow == name })
    }

    /// The environment for a script of `workflow`.
    func environment(for workflow: Workflow, variables: [String: String] = [:]) -> [String: String] {
        workflow.environment(data: dataFolder, cache: cacheFolder, extra: variables)
    }
}
