import AppKit
import ApplicationServices

/// What was selected in the front app when the selection hotkey was pressed.
enum Selection: Equatable {
    case files([URL])
    case text(String, source: String)
    case nothing
    /// Reading selected text needs Accessibility, which Reach does not have yet.
    case noAccess
}

/// Reads the macOS selection: Finder's selected files through Apple Events,
/// other apps' selected text through Accessibility, with ⌘C as a fallback
/// for apps that do not expose their selection (the pasteboard is restored).
enum SelectionReader {
    static let accessibilitySettings =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

    static func read() async -> Selection {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return .nothing }
        if app.bundleIdentifier == "com.apple.finder", let files = finderSelection(), !files.isEmpty {
            return .files(files)
        }
        guard AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) else {
            return .noAccess
        }
        let source = app.localizedName ?? "the app"
        if let text = selectedText(in: app), !text.isEmpty { return .text(text, source: source) }
        if let text = await copiedText(), !text.isEmpty { return .text(text, source: source) }
        return .nothing
    }

    private static func finderSelection() -> [URL]? {
        let source = """
        tell application "Finder"
            set out to ""
            repeat with f in (selection as alias list)
                set out to out & POSIX path of f & linefeed
            end repeat
            return out
        end tell
        """
        var error: NSDictionary?
        guard let paths = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue else {
            if let error { actionLog.error("Finder selection: \(String(describing: error), privacy: .public)") }
            return nil
        }
        return paths.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
    }

    /// The focused element's selected text, for apps that expose it (TextEdit, Safari).
    private static func selectedText(in app: NSRunningApplication) -> String? {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    /// Presses ⌘C in the front app and reads what it copied, then puts the
    /// pasteboard back the way it was.
    private static func copiedText() async -> String? {
        let board = NSPasteboard.general
        let saved = board.pasteboardItems?.map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        } ?? []
        let before = board.changeCount
        let source = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: down)  // C
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
        try? await Task.sleep(for: .milliseconds(200))
        guard board.changeCount != before else { return nil }
        let text = board.string(forType: .string)
        board.clearContents()
        board.writeObjects(saved.map { pairs in
            let item = NSPasteboardItem()
            for (type, data) in pairs { item.setData(data, forType: type) }
            return item
        })
        return text
    }
}
