import AppKit
import ReachKit

extension Snapshot {
    /// S-062 on the Hello World example: a line being dragged from Open URL,
    /// the same line over a card that refuses it, and the context menu on a line.
    static func captureConnections(dir: String, window: () -> NSWindow?) async {
        let library = WorkflowLibrary.shared
        let shots: [(String, WorkflowConnecting)] = [
            ("workflows-connecting", WorkflowConnecting(from: "WEB", point: CGPoint(x: 240, y: 40))),
            ("workflows-connect-refused", WorkflowConnecting(
                from: "WEB", point: CGPoint(x: 120, y: 108), target: "HELLO",
                refusal: WorkflowRefusal.intoInput.errorDescription)),
        ]
        for (name, connecting) in shots {
            library.connecting = connecting
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                try? await Task.sleep(for: .seconds(0.8))
                capture(to: "\(dir)/\(name)-\(mode).png", window: window())
            }
        }
        library.connecting = nil
        // The context menu on the line from the script filter to Copy to Clipboard, at its middle.
        guard let example = library.selected, let window = window(), let view = window.contentView else { return }
        let positions = WorkflowLayout.positions(example)
        guard let start = positions["HELLO"], let end = positions["COPY"] else { return }
        let from = CanvasSpace.output(start), to = CanvasSpace.input(end)
        let middle = CGPoint(x: library.canvasOrigin.x + (from.x + to.x) / 2, y: library.canvasOrigin.y + (from.y + to.y) / 2)
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            try? await Task.sleep(for: .seconds(0.8))
            popUpAndCapture(lineMenu(modifiers: 0), at: middle, in: view, to: "\(dir)/workflows-line-menu-\(mode).png")
        }
    }

    /// The same items as `ConnectionMenu`, as the NSMenu SwiftUI shows for it.
    private static func lineMenu(modifiers: Int) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Delete Connection", action: nil, keyEquivalent: "")
        let modifier = NSMenuItem(title: "Modifier", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for option in ConnectionModifier.all {
            let item = submenu.addItem(withTitle: option.title, action: nil, keyEquivalent: "")
            item.state = option.flag == modifiers ? .on : .off
        }
        modifier.submenu = submenu
        menu.addItem(modifier)
        for item in menu.items { item.target = nil }
        menu.autoenablesItems = false
        return menu
    }

    /// Shows `menu` at `point` (in `view`, top left origin) and captures the window
    /// with the menu over it, from a timer that runs while the menu tracks.
    private static func popUpAndCapture(_ menu: NSMenu, at point: CGPoint, in view: NSView, to path: String) {
        guard let window = view.window else { return }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        let frame = window.frame
        let top = (NSScreen.screens.first?.frame.height ?? frame.maxY) - frame.maxY
        // The timer fires on the main run loop while the menu tracks.
        nonisolated(unsafe) let tracked = menu
        let timer = Timer(timeInterval: 0.6, repeats: false) { _ in
            try? FileManager.default.removeItem(atPath: path)
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-R", "\(Int(frame.minX)),\(Int(top)),\(Int(frame.width)),\(Int(frame.height))", path]
            try? shot.run()
            shot.waitUntilExit()
            print("SNAPSHOT \(path)")
            MainActor.assumeIsolated { tracked.cancelTracking() }
        }
        RunLoop.main.add(timer, forMode: .common)
        let location = view.isFlipped ? point : CGPoint(x: point.x, y: view.bounds.height - point.y)
        menu.popUp(positioning: nil, at: location, in: view)
    }
}
