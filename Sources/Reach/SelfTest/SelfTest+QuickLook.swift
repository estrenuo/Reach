import AppKit
import Quartz
import SwiftData
import ReachKit

extension SelfTest {
    /// S-012: a tap on ⇧ or ⌘Y opens Quick Look on the selected file; a second
    /// tap or Esc closes it. Real key and modifier events, a real Quick Look panel.
    static func checkQuickLook(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let quickLook = QuickLook.shared
        let settings = PreviewSettings.shared
        let fm = FileManager.default
        let root = NSTemporaryDirectory() + "reach-quicklook/"
        try? fm.removeItem(atPath: root)
        try? fm.createDirectory(atPath: root, withIntermediateDirectories: true)
        fm.createFile(atPath: root + "notes.txt", contents: Data("Quick Look".utf8))
        var clock = ProcessInfo.processInfo.systemUptime
        func event(_ type: NSEvent.EventType, _ code: UInt16, _ flags: NSEvent.ModifierFlags, _ chars: String = "") -> NSEvent? {
            clock += 0.08
            return NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: clock,
                                    windowNumber: launcher.panel.windowNumber, context: nil, characters: chars,
                                    charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code)
        }
        func send(_ e: NSEvent?) { if let e { _ = launcher.handle(e) } }
        func state() -> String {
            "launcher \(launcher.isVisible ? "shown" : "hidden"), key \(NSApp.keyWindow.map { String(describing: type(of: $0)) } ?? "none"), "
                + "Quick Look \(quickLook.isOpen ? "open" : "closed"), app \(NSApp.isActive ? "active" : "inactive"), last toggle \(quickLook.lastToggle)"
        }
        func tapShift() async {
            clock += 1  // well after any typing
            send(event(.flagsChanged, 56, .shift))
            send(event(.flagsChanged, 56, []))
            try? await Task.sleep(for: .milliseconds(400))
        }

        launcher.show()
        lm.query = root
        try? await Task.sleep(for: .milliseconds(400))
        check("the test file is selected", lm.selectedResult?.title == "notes.txt", lm.selectedResult?.title ?? "none")
        await tapShift()
        check("a tap on ⇧ opens Quick Look on the selected file",
              quickLook.isOpen && quickLook.url?.lastPathComponent == "notes.txt")
        check("the launcher stays open and keeps the keyboard", launcher.isVisible && launcher.panel.isKeyWindow, state())
        await tapShift()
        check("a second tap closes it", !quickLook.isOpen, state())
        await tapShift()
        send(event(.keyDown, 53, [], "\u{1b}"))
        try? await Task.sleep(for: .milliseconds(500))
        check("Esc closes only Quick Look", !quickLook.isOpen && launcher.isVisible && lm.query == root, state())
        clock += 1
        send(event(.flagsChanged, 56, .shift))
        send(event(.keyDown, 0, .shift, "A"))
        send(event(.flagsChanged, 56, []))
        try? await Task.sleep(for: .milliseconds(300))
        check("⇧ held for a capital opens nothing", !quickLook.isOpen)
        lm.query = root
        try? await Task.sleep(for: .milliseconds(300))
        send(event(.keyDown, 16, .command, "y"))
        try? await Task.sleep(for: .milliseconds(400))
        check("⌘Y opens Quick Look", quickLook.isOpen)
        send(event(.keyDown, 16, .command, "y"))
        try? await Task.sleep(for: .milliseconds(500))
        check("and closes it", !quickLook.isOpen, state())
        settings.skips.types = ["public.text"]
        await tapShift()
        check("a skipped file type gets no Quick Look", !quickLook.isOpen)
        settings.skips = PreviewSkips(folders: [URL(fileURLWithPath: root).resolvingSymlinksInPath().path])
        await tapShift()
        check("nor does a file in a skipped folder", !quickLook.isOpen)
        settings.skips = PreviewSkips()
        settings.quickLook = false
        await tapShift()
        check("nor anything with Quick Look off in Settings", !quickLook.isOpen)
        settings.quickLook = true
        await tapShift()
        launcher.hide()
        try? await Task.sleep(for: .milliseconds(500))
        check("hiding the launcher closes Quick Look", !quickLook.isOpen, state())
        // Hidden while Quick Look is still opening, as after a tap on ⇧ and a click elsewhere.
        launcher.show()
        lm.query = root
        try? await Task.sleep(for: .milliseconds(400))
        clock += 1
        send(event(.flagsChanged, 56, .shift))
        send(event(.flagsChanged, 56, []))
        launcher.hide()
        try? await Task.sleep(for: .milliseconds(1000))
        check("hiding it mid-animation closes Quick Look too", !quickLook.isOpen, state())

        // As in real use: another app in front, and ⇧ tapped on the real keyboard,
        // so the event takes the system's path through the key monitor.
        if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
            finder.activate()
            try? await Task.sleep(for: .milliseconds(500))
        }
        launcher.show()
        lm.query = root
        try? await Task.sleep(for: .milliseconds(500))
        func realShift() async {
            let source = CGEventSource(stateID: .hidSystemState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 56, keyDown: true)
            down?.flags = .maskShift
            down?.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(60))
            let up = CGEvent(keyboardEventSource: source, virtualKey: 56, keyDown: false)
            up?.flags = []
            up?.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(700))
        }
        await realShift()
        check("with another app in front, a real ⇧ tap opens Quick Look and the launcher stays", quickLook.isOpen && launcher.isVisible, state())
        await realShift()
        // Under load Quick Look's closing animation can take longer than the pause after the tap.
        for _ in 0..<40 where quickLook.isOpen { try? await Task.sleep(for: .milliseconds(25)) }
        check("and a second real tap closes it", !quickLook.isOpen, state())
        launcher.hide()

        // In the action panel: ⇧, ⌘Y and the Quick Look row preview the panel's file.
        launcher.show()
        lm.query = root
        try? await Task.sleep(for: .milliseconds(400))
        _ = lm.showActions()
        let row = lm.actions?.items.firstIndex(of: .action(.quickLook))
        check("the action panel lists Quick Look", row == 1, "\(lm.actions?.items ?? [])")
        await tapShift()
        check("a tap on ⇧ in the action panel opens Quick Look on its file",
              quickLook.isOpen && quickLook.url?.lastPathComponent == "notes.txt" && lm.actions != nil && launcher.isVisible, state())
        send(event(.keyDown, 53, [], "\u{1b}"))
        try? await Task.sleep(for: .milliseconds(500))
        check("Esc closes Quick Look first, the action panel stays", !quickLook.isOpen && lm.actions != nil, state())
        send(event(.keyDown, 16, .command, "y"))
        try? await Task.sleep(for: .milliseconds(400))
        check("⌘Y in the action panel opens Quick Look", quickLook.isOpen, state())
        send(event(.keyDown, 16, .command, "y"))
        try? await Task.sleep(for: .milliseconds(500))
        check("and closes it", !quickLook.isOpen, state())
        if let row { lm.runAction(at: row) }
        try? await Task.sleep(for: .milliseconds(400))
        check("↩ on Quick Look opens it, and the launcher stays", quickLook.isOpen && launcher.isVisible && lm.actions != nil, state())
        quickLook.close()
        lm.closeActions()
        settings.skips.types = ["public.text"]
        _ = lm.showActions()
        check("a skipped file type gets no Quick Look row", lm.actions?.items.contains(.action(.quickLook)) == false)
        settings.skips = PreviewSkips()
        lm.closeActions()
        lm.query = "zzqxv nothing"
        try? await Task.sleep(for: .milliseconds(300))
        launcher.hide()
        check("test runs leave the saved preview settings alone",
              UserDefaults.standard.object(forKey: "previews.skipTypes") as? [String] != ["public.text"])
        try? fm.removeItem(atPath: root)
    }
}
