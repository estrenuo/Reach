import AppKit
import ReachKit

/// One launcher capture: its file name, what is typed, and what to set up first.
/// `prepare` runs after the query is typed and the results settled; `cleanUp`
/// runs after the capture. With `workflow`, a sample workflow sits in the
/// library for the length of the shot.
struct LauncherShot {
    var name: String
    var query: String = ""
    var workflow: (folder: String, plist: [String: Any])? = nil
    var prepare: @MainActor (AppModel) async -> Void = { _ in }
    var cleanUp: @MainActor (AppModel) -> Void = { _ in }
}

extension Snapshot {
    /// Captures every shot as launcher-<name>-<mode>.png, in light and then in dark.
    static func captureLauncher(_ shots: [LauncherShot], model: AppModel, dir: String) async {
        guard let launcher = model.launcher else { return }
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            for shot in shots {
                let take = {
                    launcher.show()
                    model.launcherModel.query = shot.query
                    try? await Task.sleep(for: .seconds(1))
                    await shot.prepare(model)
                    capture(to: "\(dir)/launcher-\(shot.name)-\(mode).png", window: launcher.panel)
                    shot.cleanUp(model)
                    _ = model.launcherModel.clearBuffer()
                    launcher.hide()
                }
                if let workflow = shot.workflow {
                    await withSampleWorkflow(workflow.folder, workflow.plist, take)
                } else {
                    await take()
                }
            }
        }
    }

    /// A sample workflow in the library, in `<folder>.workflow` with this
    /// `info.plist`, for the length of `body`.
    static func withSampleWorkflow(_ folder: String, _ plist: [String: Any], _ body: () async -> Void) async {
        let library = WorkflowLibrary.shared
        let url = library.folder.appending(path: "\(folder).workflow", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: url.appending(path: "info.plist"))
        library.reload()
        await body()
        try? FileManager.default.removeItem(at: url)
        library.reload()
    }
}
