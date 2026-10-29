import AppKit
import ApplicationServices
import Carbon
import ReachKit
import SwiftData

/// Settings > Snippets (S-031). Saved in `Store.settings`.
@Observable
final class SnippetSettings {
    static let shared = SnippetSettings()

    /// Off at first: it watches every key, and needs Accessibility.
    var expandsWhileTyping: Bool { didSet { Store.settings.set(expandsWhileTyping, forKey: "snippets.expand") } }

    private init() {
        expandsWhileTyping = Store.settings.bool(forKey: "snippets.expand")
    }

    /// Back to the standard settings; the self-test leaves no trace this way.
    func reset() { expandsWhileTyping = false }
}

/// Replaces a snippet keyword typed in any app with the snippet (S-031), only
/// while Expand is on. A global monitor sees keys without taking them. It keeps
/// the last few characters in memory, never on disk or in a log, and skips
/// password fields and Reach itself.
final class SnippetExpander {
    let launcher: LauncherModel
    let settings: SnippetSettings
    /// The front app's bundle id. The self-test swaps in a fake.
    var frontApp: @MainActor () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
    /// True in a password field, or while an app has turned on secure input. The self-test swaps in a fake.
    var isSecure: @MainActor () -> Bool = { SnippetExpander.focusIsSecure() }
    /// Presses Delete in the front app. The self-test swaps in a recorder.
    var deleter: @MainActor (Int) -> Void = { Paster.pressDelete($0) }
    private(set) var buffer = TypedBuffer()
    private var monitor: Any?
    private var activation: Any?
    private var cache: (keywords: [String: String], at: Date)?

    init(launcher: LauncherModel, settings: SnippetSettings = .shared) {
        self.launcher = launcher
        self.settings = settings
    }

    var isWatching: Bool { monitor != nil }

    /// Starts or stops watching to match the setting, now and whenever it changes.
    func follow() {
        withObservationTracking {
            update(on: settings.expandsWhileTyping)
        } onChange: { [weak self] in
            DispatchQueue.main.async { self?.follow() }
        }
    }

    private func update(on: Bool) {
        if on, monitor == nil {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                MainActor.assumeIsolated { self?.handle(event) }
            }
            activation = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.buffer.reset() }
            }
        } else if !on, let monitor {
            NSEvent.removeMonitor(monitor)
            activation.map(NSWorkspace.shared.notificationCenter.removeObserver)
            self.monitor = nil
            activation = nil
            buffer.reset()
        }
    }

    /// One key or click from any app. A click or a key that moves the caret
    /// starts over, since what comes before the caret is then unknown.
    func handle(_ event: NSEvent) {
        if event.cgEvent?.getIntegerValueField(.eventSourceUserData) == Paster.marker { return }
        guard event.type == .keyDown else { return buffer.reset() }
        if !event.modifierFlags.intersection(.deviceIndependentFlagsMask).isDisjoint(with: [.command, .control]) {
            return buffer.reset()
        }
        switch Int(event.keyCode) {
        case kVK_Delete: return buffer.backspace()
        case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Tab: return buffer.type("\n")
        case kVK_Escape, kVK_ForwardDelete, kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown,
             kVK_LeftArrow, kVK_RightArrow, kVK_DownArrow, kVK_UpArrow: return buffer.reset()
        default: break
        }
        guard let typed = event.characters, !typed.isEmpty,
              typed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return buffer.reset() }
        buffer.type(typed)
        expandIfTyped()
    }

    private func expandIfTyped() {
        let snippets = keywords()
        guard let keyword = buffer.match(snippets.keys), let text = snippets[keyword] else { return }
        buffer.reset()
        guard frontApp() != Bundle.main.bundleIdentifier, !isSecure() else { return }
        deleter(keyword.count)
        launcher.pasteSnippet(text, hiding: false)
    }

    /// Keyword to snippet text, read again at most once a second while typing.
    /// Two snippets with one keyword: the first by name wins, as in `snip`.
    private func keywords() -> [String: String] {
        if let cache, Date.now.timeIntervalSince(cache.at) < 1 { return cache.keywords }
        var found: [String: String] = [:]
        for snippet in launcher.snippets.all() where !snippet.keyword.isEmpty && found[snippet.keyword] == nil {
            found[snippet.keyword] = snippet.text
        }
        cache = (found, .now)
        return found
    }

    /// Forgets the read keywords, so the next key reads them again (the self-test).
    func forgetKeywords() { cache = nil }

    /// A password field, by its Accessibility subrole, or secure input (Terminal, password prompts).
    static func focusIsSecure() -> Bool {
        if IsSecureEventInputEnabled() { return true }
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSubroleAttribute as CFString, &subrole)
        return subrole as? String == kAXSecureTextFieldSubrole
    }
}
