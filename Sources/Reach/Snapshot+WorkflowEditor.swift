import AppKit
import ReachKit

extension Snapshot {
    /// S-063: the palette beside the canvas, its categories collapsed and the
    /// search field empty, in the Workflows window `window` returns.
    static func capturePalette(dir: String, window: () -> NSWindow?) async {
        let palette = WorkflowPaletteState.shared
        palette.filter = ""
        palette.expanded = []
        palette.shown = true
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            try? await Task.sleep(for: .seconds(0.8))
            capture(to: "\(dir)/workflows-palette-\(mode).png", window: window())
        }
        palette.shown = false
    }
}
