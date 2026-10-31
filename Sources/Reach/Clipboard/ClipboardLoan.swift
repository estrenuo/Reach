import AppKit
import ReachKit

/// Copies text, and pastes it into the front app with a ⌘V keystroke.
/// Posting keys needs the Accessibility permission the selection hotkey uses;
/// without it the answer is still on the clipboard.
enum Paster {
    /// Marks the keys Reach presses itself, so its own key monitors skip them (S-031).
    static let marker: Int64 = 0x5245_4143

    /// Presses Delete `count` times in the front app, for a snippet keyword.
    static func pressDelete(_ count: Int) {
        press(key: 51, flags: [], times: count)
    }

    private static func press(key: CGKeyCode, flags: CGEventFlags, times: Int = 1) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for _ in 0..<times {
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
                event?.flags = flags
                event?.setIntegerValueField(.eventSourceUserData, value: marker)
                event?.post(tap: .cghidEventTap)
            }
        }
    }

    /// Presses a workflow's keys in the front app once the launcher has hidden (S-053).
    /// False without the Accessibility permission, which posting keys needs.
    static func press(_ keys: WorkflowKeys) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            press(key: CGKeyCode(keys.keyCode), flags: CGEventFlags(rawValue: UInt64(keys.modifiers)), times: keys.count)
        }
        return true
    }

    /// Presses ⌘C in the front app, for the selection hotkey.
    static func pressCopy() {
        press(key: 8, flags: .maskCommand)  // C
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Waits for the launcher to hide, so the keystroke reaches the app behind it.
    static func pressPaste() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            press(key: 9, flags: .maskCommand)  // V
        }
    }
}

/// The clipboard as it was, kept while Reach uses it for a moment: to paste
/// a snippet, or to read a selection with ⌘C. Clipboard History pauses for
/// the loan, so neither Reach's own copy nor the clipboard put back counts as
/// a new clip. A private copy, like a password, is not kept and not put back:
/// putting it back would stop the password manager from clearing it.
final class ClipboardLoan {
    let board: NSPasteboard
    let history: ClipboardHistory?
    /// Marked private or machine-made (nspasteboard.org).
    let isPrivate: Bool
    private let saved: [NSPasteboardItem]
    private let start: Int
    private var ours: Int?

    init(_ board: NSPasteboard, history: ClipboardHistory?) {
        self.board = board
        self.history = history
        isPrivate = !Set(board.types?.map(\.rawValue) ?? []).isDisjoint(with: ClipboardPolicy.ignoredTypes)
        // Every item's data now: the items themselves die with `clearContents`.
        saved = isPrivate ? [] : (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
        start = board.changeCount
        history?.isPaused = true
    }

    /// Reach, or the front app for Reach, has written to the clipboard.
    func took() { ours = board.changeCount }

    /// Puts the clipboard back, unless nothing was taken or someone copied
    /// since. Ends the pause either way; a copy made meanwhile is kept by the next poll.
    func giveBack() {
        defer { history?.isPaused = false }
        guard let ours, ours != start, board.changeCount == ours else { return }
        board.clearContents()
        if !saved.isEmpty { board.writeObjects(saved) }
        history?.skipCurrent()
    }
}
