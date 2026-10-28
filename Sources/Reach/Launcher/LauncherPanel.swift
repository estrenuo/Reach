import AppKit
import SwiftUI

/// A floating panel that takes typing but leaves the other app in front,
/// so focus goes straight back to it when the launcher hides.
final class LauncherPanel: NSPanel {
    var onResign: () -> Void = {}

    init(content: some View) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: LauncherLayout.width, height: LauncherLayout.height(rows: 0)),
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        setAccessibilityLabel("Launcher")
        let host = NSHostingView(rootView: content)
        host.sizingOptions = []
        contentView = host
    }

    override var canBecomeKey: Bool { true }

    /// A click outside hides the launcher.
    override func resignKey() {
        super.resignKey()
        onResign()
    }
}

/// Shows, hides, sizes, and places the launcher, and turns keys into model actions.
final class LauncherController {
    let model: LauncherModel
    let panel: LauncherPanel
    private var keyMonitor: Any?

    var isVisible: Bool { panel.isVisible }

    init(model: LauncherModel) {
        self.model = model
        panel = LauncherPanel(content: LauncherView(model: model).themed())
        panel.onResign = { [weak self] in self?.hide() }
        model.onHide = { [weak self] in self?.hide() }
        model.onResultsChange = { [weak self] in self?.resize() }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        model.didShow()
        place()
        panel.orderFrontRegardless()
        panel.makeKey()
        installKeys()
    }

    func hide() {
        guard isVisible else { return }
        removeKeys()
        panel.orderOut(nil)
        model.didHide()
    }

    /// Centred on the screen with the mouse, a fifth of the way down.
    private func place() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        let height = LauncherLayout.height(for: model)
        let top = area.maxY - area.height * 0.2
        panel.setFrame(NSRect(x: area.midX - LauncherLayout.width / 2, y: top - height,
                              width: LauncherLayout.width, height: height), display: true)
    }

    /// Grows and shrinks downward: the search field stays where it is.
    private func resize() {
        let height = LauncherLayout.height(for: model)
        let frame = panel.frame
        guard frame.height != height else { return }
        panel.setFrame(NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height),
                       display: true)
        panel.invalidateShadow()
    }

    private func installKeys() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeys() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// True when the key was used. Keys typed into an input method pass through.
    func handle(_ event: NSEvent) -> Bool {
        if let editor = panel.firstResponder as? NSTextView, editor.hasMarkedText() { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command, let key = event.charactersIgnoringModifiers {
            if key == "," {
                hide()
                model.openSettings()
                return true
            }
            if let number = Int(key), (1...9).contains(number) {
                model.open(at: number - 1)
                return true
            }
        }
        switch event.keyCode {
        case 126: model.move(-1)
        case 125: model.move(1)
        case 36, 76: model.openSelected()
        case 53: model.cancel()
        // While browsing: → and Tab go into a folder, ← goes back up.
        // Otherwise they move the text cursor as usual.
        case 124 where flags.isEmpty: return model.enter()
        case 123 where flags.isEmpty: return model.back()
        case 48 where flags.isEmpty: return model.complete()
        default: return false
        }
        return true
    }
}
