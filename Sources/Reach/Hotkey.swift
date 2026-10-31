import AppKit
import Carbon.HIToolbox
import ReachKit

/// The global launcher hotkey, through Carbon: no permission needed, and the
/// key never reaches the front app.
@Observable
final class HotkeyCenter {
    static let shared = HotkeyCenter()
    private static let signature = OSType(0x5245_4348)  // 'RECH'

    private(set) var combo: KeyCombo
    private(set) var keyName: String
    /// False when the system refused the combination (another app owns it).
    private(set) var isRegistered = false
    var onPress: () -> Void = {}
    /// The selection hotkey (S-011): the action panel for the macOS selection.
    var onSelection: () -> Void = {}
    /// False when another app owns the selection hotkey.
    private(set) var selectionRegistered = false
    private var selectionRef: EventHotKeyRef?
    /// The clipboard hotkey (S-026): the clipboard viewer.
    var onClipboard: () -> Void = {}
    /// False when another app owns the clipboard hotkey.
    private(set) var clipboardRegistered = false
    private var clipboardRef: EventHotKeyRef?
    private static let launcherID: UInt32 = 1
    private static let selectionID: UInt32 = 3
    private static let clipboardID: UInt32 = 4
    /// Workflow hotkeys (S-049) take ids from here on.
    static let firstWorkflowID: UInt32 = 100
    /// A workflow hotkey was pressed, by its id.
    var onWorkflow: (UInt32) -> Void = { _ in }
    private var workflowRefs: [EventHotKeyRef] = []

    private var ref: EventHotKeyRef?
    private var handlerInstalled = false

    private init() {
        let defaults = Store.settings
        if let data = defaults.data(forKey: "hotkey.combo"),
           let saved = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            combo = saved
            keyName = defaults.string(forKey: "hotkey.key") ?? Self.name(for: saved.keyCode, characters: nil)
        } else {
            combo = .default
            keyName = "Space"
        }
    }

    var display: String { combo.display(key: keyName) }
    var spoken: String { combo.spoken(key: keyName) }

    /// Installs the event handler; registers the saved hotkey unless `register` is false.
    func start(register: Bool = true) {
        installHandler()
        if register {
            isRegistered = self.register(combo)
            selectionRegistered = registerSelection()
            clipboardRegistered = registerFixed(.clipboard, id: Self.clipboardID, ref: &clipboardRef)
        }
    }

    /// Switches to `new`. When the system refuses it, the old hotkey stays and this returns false.
    @discardableResult
    func change(to new: KeyCombo, keyName newName: String) -> Bool {
        let old = combo
        unregister()
        guard register(new) else {
            isRegistered = register(old)
            return false
        }
        combo = new
        keyName = newName
        isRegistered = true
        Store.settings.set(try? JSONEncoder().encode(new), forKey: "hotkey.combo")
        Store.settings.set(newName, forKey: "hotkey.key")
        return true
    }

    /// While Settings records a new hotkey, the old one must not show the launcher.
    func suspend() { unregister() }
    func resume() { if ref == nil { isRegistered = register(combo) } }

    /// Reach's own hotkeys, which a workflow hotkey never takes (S-049).
    var reserved: [(name: String, combo: KeyCombo)] {
        [("launcher hotkey", combo), ("selection hotkey", .selection), ("clipboard hotkey", .clipboard)]
    }

    /// Registers a workflow hotkey; false when another app owns the combination.
    func registerWorkflow(_ combo: KeyCombo, id: UInt32) -> Bool {
        var ref: EventHotKeyRef?
        let hotkey = EventHotKeyID(signature: Self.signature, id: id)
        guard RegisterEventHotKey(combo.keyCode, combo.modifiers, hotkey, GetApplicationEventTarget(), 0, &ref) == noErr,
              let ref else { return false }
        workflowRefs.append(ref)
        return true
    }

    func unregisterWorkflows() {
        workflowRefs.forEach { UnregisterEventHotKey($0) }
        workflowRefs = []
    }

    /// True when this app could take `combo` right now; used by the self-test.
    func isFree(_ combo: KeyCombo) -> Bool {
        var probe: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: 2)
        guard RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &probe) == noErr
        else { return false }
        if let probe { UnregisterEventHotKey(probe) }
        return true
    }

    private func registerSelection() -> Bool {
        registerFixed(.selection, id: Self.selectionID, ref: &selectionRef)
    }

    /// A hotkey people cannot change yet, like the selection's and the clipboard's.
    private func registerFixed(_ combo: KeyCombo, id: UInt32, ref: inout EventHotKeyRef?) -> Bool {
        let hotkey = EventHotKeyID(signature: Self.signature, id: id)
        return RegisterEventHotKey(combo.keyCode, combo.modifiers, hotkey, GetApplicationEventTarget(), 0, &ref) == noErr
    }

    /// Which hotkey was pressed: the launcher's, the selection's or the clipboard's.
    fileprivate func pressed(_ id: UInt32) {
        switch id {
        case Self.selectionID: onSelection()
        case Self.clipboardID: onClipboard()
        case Self.firstWorkflowID...: onWorkflow(id)
        default: onPress()
        }
    }

    private func register(_ combo: KeyCombo) -> Bool {
        let id = EventHotKeyID(signature: Self.signature, id: Self.launcherID)
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &newRef)
        guard status == noErr else { return false }
        ref = newRef
        return true
    }

    private func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        isRegistered = false
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotkey = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkey)
            let id = hotkey.id
            Task { @MainActor in HotkeyCenter.shared.pressed(id) }
            return noErr
        }, 1, &spec, nil, nil)
    }

    /// "Space", "F5", "↑", or the key's character.
    static func name(for keyCode: UInt32, characters: String?) -> String {
        let named: [UInt32: String] = [
            49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 53: "Esc",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        if let name = named[keyCode] { return name }
        return (characters ?? "?").uppercased()
    }

    /// Carbon modifier bits from an AppKit event.
    static func modifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var bits: UInt32 = 0
        if flags.contains(.command) { bits |= KeyCombo.command }
        if flags.contains(.option) { bits |= KeyCombo.option }
        if flags.contains(.control) { bits |= KeyCombo.control }
        if flags.contains(.shift) { bits |= KeyCombo.shift }
        return bits
    }
}
