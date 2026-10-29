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
        // A list, one item per file: a name may hold any character, even a line break.
        let source = """
        tell application "Finder"
            set out to {}
            repeat with f in (selection as alias list)
                set end of out to POSIX path of f
            end repeat
            return out
        end tell
        """
        var error: NSDictionary?
        guard let list = NSAppleScript(source: source)?.executeAndReturnError(&error) else {
            if let error { actionLog.error("Finder selection: \(String(describing: error), privacy: .public)") }
            return nil
        }
        guard list.numberOfItems > 0 else { return [] }
        return (1...list.numberOfItems).compactMap { index in
            guard let path = list.atIndex(index)?.stringValue,
                  FileManager.default.fileExists(atPath: path) else { return nil }
            return URL(fileURLWithPath: path)
        }
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
    /// clipboard back through a `ClipboardLoan`: a password is not put back,
    /// and Clipboard History keeps neither the selection nor the restore.
    /// The self-test passes a private pasteboard and a fake ⌘C.
    static func copiedText(board: NSPasteboard = .general, history: ClipboardHistory? = AppModel.shared.clipboard,
                           pressCopy: () -> Void = { Paster.pressCopy() }, wait: Duration = .milliseconds(200)) async -> String? {
        let loan = ClipboardLoan(board, history: history)
        defer { loan.giveBack() }
        let before = board.changeCount
        pressCopy()
        try? await Task.sleep(for: wait)
        guard board.changeCount != before else { return nil }
        loan.took()
        return board.string(forType: .string)
    }
}
