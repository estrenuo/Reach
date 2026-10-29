import AppKit
import ReachKit

extension SelfTest {
    /// S-023: ⌘L shows the selected result in Large Type and hides the
    /// launcher; ⌘⌥L the typed text. The card fits the text, centred on the
    /// screen with the mouse; a real Esc or a real click closes it.
    static func checkLargeType(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let large = LargeType.shared
        func commandL(option: Bool = false) -> Bool {
            let flags: NSEvent.ModifierFlags = option ? [.command, .option] : .command
            guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                                               timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: launcher.panel.windowNumber,
                                               context: nil, characters: option ? "¬" : "l", charactersIgnoringModifiers: "l",
                                               isARepeat: false, keyCode: 37) else { return false }
            return launcher.handle(event)
        }
        func reopen(_ query: String) async {
            large.hide()
            launcher.show()
            // Hide, show and a query in one run loop turn trip AppKit (see FIXLOG).
            try? await Task.sleep(for: .milliseconds(300))
            lm.query = query
        }
        defer { large.hide() }

        await reopen("=2*21")
        check("⌘L is handled", commandL())
        try? await Task.sleep(for: .milliseconds(300))
        check("⌘L shows the calculation's answer and hides the launcher",
              large.isVisible && large.text == "42" && !launcher.isVisible, "“\(large.text)”")
        if let screen = large.window?.screen ?? NSScreen.main, let frame = large.window?.frame {
            check("the card is centred on the screen", abs(frame.midX - screen.visibleFrame.midX) <= 1
                  && abs(frame.midY - screen.visibleFrame.midY) <= 1)
        }

        // A real Esc, through the system, as from the keyboard.
        NSApp.activate()
        large.window?.makeKey()
        try? await Task.sleep(for: .milliseconds(200))
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] { CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: down)?.post(tap: .cghidEventTap) }
        try? await Task.sleep(for: .milliseconds(400))
        check("Esc closes it", !large.isVisible)

        await reopen("=2*21")
        _ = commandL(option: true)
        try? await Task.sleep(for: .milliseconds(300))
        check("⌘⌥L shows the typed text", large.isVisible && large.text == "=2*21", "“\(large.text)”")
        // A real click on the card.
        if let frame = large.window?.frame, let screen = NSScreen.screens.first {
            NSApp.activate()
            large.window?.makeKey()
            try? await Task.sleep(for: .milliseconds(200))
            let point = CGPoint(x: frame.midX, y: screen.frame.maxY - frame.midY)
            for type in [CGEventType.leftMouseDown, .leftMouseUp] {
                CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
            }
            try? await Task.sleep(for: .milliseconds(400))
        }
        check("a click closes it", !large.isVisible)

        await reopen("zzqxv nothing")
        _ = commandL()
        try? await Task.sleep(for: .milliseconds(300))
        check("on a web search fallback ⌘L shows the typed text", large.text == "zzqxv nothing", "“\(large.text)”")

        await reopen("")
        check("with nothing typed ⌘L shows nothing", lm.largeTypeText() == nil && !lm.showLargeType())

        large.show("Hi")
        let short = large.window?.frame.width ?? 0
        large.show(String(repeating: "Large Type wraps long text. ", count: 8))
        let long = large.window?.frame ?? .zero
        let room = (large.window?.screen ?? NSScreen.main)?.visibleFrame.width ?? 0
        check("the card fits the text: short text gets a small card", short > 0 && short < long.width / 2, "\(short) vs \(long.width)")
        check("long text shrinks and wraps within 90% of the screen", long.width <= room * 0.9 + 1
              && large.fontSize >= 12 && large.fontSize < LargeType.maxSize, "\(large.fontSize) pt")
        large.hide()
        launcher.hide()
    }
}
