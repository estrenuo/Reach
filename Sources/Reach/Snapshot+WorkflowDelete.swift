import AppKit

extension Snapshot {
    /// S-065: two cards selected (⌘-click), ready for Delete.
    static func captureWorkflowsMultiSelect(dir: String, window: () -> NSWindow?) async {
        let library = WorkflowLibrary.shared
        library.selectedObjects = ["COPY", "WEB"]
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            try? await Task.sleep(for: .seconds(0.8))
            capture(to: "\(dir)/workflows-multiselect-\(mode).png", window: window())
        }
        library.selectedObjects = []
    }
}
