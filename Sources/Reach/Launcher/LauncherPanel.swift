import AppKit
import Quartz
import ReachKit
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

    // Quick Look looks for its controller along the key window's responder chain.
    // AppKit calls these on the main thread, but declares them nonisolated.
    nonisolated override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    nonisolated override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated { panel.dataSource = QuickLook.shared }
    }

    nonisolated override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated { panel.dataSource = nil }
    }
}

/// Shows, hides, sizes, and places the launcher, and turns keys into model actions.
final class LauncherController {
    let model: LauncherModel
    let panel: LauncherPanel
    private var keyMonitor: Any?
    private var shiftTap = ShiftTap()

    var isVisible: Bool { panel.isVisible }

    init(model: LauncherModel) {
        self.model = model
        panel = LauncherPanel(content: LauncherView(model: model).themed())
        panel.onResign = { [weak self] in
            // Quick Look makes itself key when it opens. Take the keyboard back,
            // so ↑, ↓ and a second ⇧ still reach the launcher.
            quickLookLog.notice("launcher lost the keyboard to \(NSApp.keyWindow.map { String(describing: type(of: $0)) } ?? "another app", privacy: .public)")
            if QuickLook.shared.keepsLauncherKey(keyWindow: NSApp.keyWindow), self?.isVisible == true {
                DispatchQueue.main.async { self?.panel.makeKey() }
                return
            }
            self?.hide()
        }
        model.onHide = { [weak self] in self?.hide() }
        model.onShow = { [weak self] in if self?.isVisible == false { self?.show() } }
        model.onResultsChange = { [weak self] in self?.resize() }
        model.onSelectionChange = { [weak self] in QuickLook.shared.follow(self?.model.selectedResult) }
        followTheme()
    }

    /// Light, dark or the Mac's mode, from the chosen theme, now and on every pick (S-032).
    private func followTheme() {
        withObservationTracking {
            panel.appearance = LauncherThemeStore.shared.theme.mode.appearance
        } onChange: { [weak self] in
            DispatchQueue.main.async { self?.followTheme() }
        }
    }

    /// Opens Settings from outside the bar, like opening Reach again from Finder (S-035).
    /// Only the launcher's view can open Settings, so it shows the bar once if it never appeared.
    func openSettings() {
        openFromOutside { $0.openSettings() }
    }

    /// Settings, Snippets and Workflows open through the launcher's view, which
    /// sets these closures when it first appears; before that it shows once.
    func openFromOutside(_ open: @escaping @MainActor (LauncherModel) -> Void) {
        guard model.canOpenSettings else {
            show()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                hide()
                open(model)
            }
            return
        }
        open(model)
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

    /// The selection hotkey: reads the selection while the other app is still
    /// in front, then shows the action panel for it.
    func showSelection() {
        Task { @MainActor in
            let selection = await model.readSelection()
            show()
            model.showActions(for: selection)
        }
    }

    /// The clipboard hotkey: shows the clipboard viewer, or hides it when it shows.
    func toggleClipboard() {
        if isVisible, model.viewer != nil { return hide() }
        show()
        model.showClipboard()
    }

    func hide() {
        guard isVisible else { return }
        QuickLook.shared.close()
        removeKeys()
        panel.orderOut(nil)
        model.didHide()
    }

    /// Centred on the chosen screen (the mouse's at first), a fifth of the way down.
    private func place() {
        guard let screen = LauncherOptionsStore.shared.screenForBar() ?? NSScreen.main else { return }
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
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            // Quick Look holds the keyboard for a moment after it opens; a ⇧ tap
            // then still counts, so a quick second tap closes it.
            let fromQuickLook = event.type == .flagsChanged && event.window is QLPreviewPanel
            guard event.window === self.panel || fromQuickLook else { return event }
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
        if event.type == .flagsChanged { return handleFlags(event) }
        shiftTap.typed(at: event.timestamp)
        // Arrow keys always carry .numericPad and .function; only the keys
        // people hold down count as modifiers.
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.numericPad, .function, .capsLock])
        // Esc closes Quick Look before anything else.
        if event.keyCode == 53, QuickLook.shared.isOpen {
            QuickLook.shared.close()
            return true
        }
        if flags == .command, event.charactersIgnoringModifiers == "y" {
            _ = QuickLook.shared.toggle(previewTarget)
            return true
        }
        // ⌘O opens a contact in Contacts.app (S-024).
        if flags == .command, event.charactersIgnoringModifiers == "o", model.openInContacts() { return true }
        if model.viewer != nil { return handleClipboard(event, flags: flags) }
        if model.actions != nil { return handleActions(event, flags: flags) }
        if flags == .option, handleBuffer(event.keyCode) { return true }
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
        if flags == .command, [36, 76].contains(event.keyCode), model.pasteSelected() { return true }
        // ⌃↩, ⌥↩, ⌘↩: the search chosen in Settings > Advanced (S-038). ⇧↩ follows
        // a workflow row's ⇧ line (S-054); elsewhere it is plain Return.
        if [36, 76].contains(event.keyCode),
           let modifier = ReturnModifier.held(control: flags == .control, option: flags == .option, command: flags == .command,
                                              shift: flags == .shift),
           model.runAlternative(modifier) { return true }
        // ⌃↑ and ⌃↓ walk the queries typed before.
        if flags == .control, [125, 126].contains(event.keyCode), model.walkHistory(older: event.keyCode == 126) { return true }
        // ⌘L shows the selected result in Large Type, ⌘⌥L the typed text (S-023).
        if event.keyCode == 37, flags == .command || flags == [.command, .option] {
            _ = model.showLargeType(typed: flags.contains(.option))
            return true
        }
        switch event.keyCode {
        case 126: model.move(-1)
        case 125: model.move(1)
        case 36, 76: model.openSelected()
        case 53: model.cancel()
        // While browsing: → and Tab go into a folder, ← goes back up.
        // Otherwise they move the text cursor as usual.
        // → on a file or app opens its action panel, once the cursor is at the end.
        case 124 where flags.isEmpty: return model.enter() || (caretAtEnd && model.showActions())
        case 123 where flags.isEmpty: return model.back()
        case 48 where flags.isEmpty: return model.complete()
        default: return false
        }
        return true
    }

    /// What ⇧ and ⌘Y preview: the action panel's file, else the selected result.
    /// Selected text has no file, so Quick Look stays shut there.
    private var previewTarget: LaunchResult? {
        model.actions?.target ?? model.selectedResult
    }

    /// A tap on ⇧ opens or closes Quick Look (S-012). Modifier changes always
    /// pass through, so ⇧ still makes capitals.
    private func handleFlags(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .function, .numericPad])
        let isShift = event.keyCode == 56 || event.keyCode == 60
        if isShift, flags == .shift {
            shiftTap.pressed(at: event.timestamp)
        } else if isShift, flags.isEmpty {
            let tap = shiftTap.released(at: event.timestamp)
            quickLookLog.debug("⇧ up: \(tap ? "tap" : "not a tap", privacy: .public)")
            if tap {
                _ = QuickLook.shared.toggle(previewTarget)
            }
        } else {
            shiftTap.interrupted()
        }
        return false
    }

    /// ⌥ keys for the buffer (S-013). ⌥↑ and ⌥↓ always belong to it; ⌥←, ⌥→
    /// and ⌥⌫ only while it has items, so they still move and delete by word.
    private func handleBuffer(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case 126: _ = model.toggleBuffer(); return true
        case 125: _ = model.addToBuffer(); return true
        case 123: return model.removeLastFromBuffer()
        case 124: return model.showBufferActions()
        case 51: return model.clearBuffer()
        default: return false
        }
    }

    /// Keys in the action panel. ← on an empty filter goes back, like Esc.
    private func handleActions(_ event: NSEvent, flags: NSEvent.ModifierFlags) -> Bool {
        guard let actions = model.actions else { return false }
        // ⌘C in a card copies the detail, unless text in the filter is selected.
        if flags == .command, event.charactersIgnoringModifiers == "c", !filterHasSelection, model.copySelectedField() { return true }
        if flags == .command, let key = event.charactersIgnoringModifiers, let number = Int(key), (1...9).contains(number) {
            model.runAction(at: number - 1)
            return true
        }
        switch event.keyCode {
        case 126: actions.move(-1)
        case 125: actions.move(1)
        case 36, 76: model.runAction(at: actions.selection)
        case 53: model.cancelActions()
        case 123 where flags.isEmpty && actions.filter.isEmpty: model.cancelActions()
        default: return false
        }
        return true
    }

    /// Keys in the clipboard viewer (S-026).
    private func handleClipboard(_ event: NSEvent, flags: NSEvent.ModifierFlags) -> Bool {
        guard let viewer = model.viewer else { return false }
        if flags == .command, event.charactersIgnoringModifiers == "c", !filterHasSelection, model.copySelectedClip() { return true }
        if flags == .command, let key = event.charactersIgnoringModifiers, let number = Int(key), (1...9).contains(number) {
            model.useClip(at: number - 1)
            return true
        }
        switch event.keyCode {
        case 126: viewer.move(-1)
        case 125: viewer.move(1)
        case 36, 76: model.useClip(at: viewer.selection)
        case 53: model.cancelClipboard()
        default: return false
        }
        return true
    }

    /// True when text in the field is selected, so ⌘C copies it as usual.
    private var filterHasSelection: Bool {
        guard let editor = panel.firstResponder as? NSTextView else { return false }
        return editor.selectedRange().length > 0
    }

    /// True when the text cursor, or the selection, reaches the end of the query.
    /// A query the launcher filled in is selected as a whole, and counts.
    private var caretAtEnd: Bool {
        guard let editor = panel.firstResponder as? NSTextView else { return true }
        return NSMaxRange(editor.selectedRange()) == (editor.string as NSString).length
    }
}
