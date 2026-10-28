import AppKit
import ReachKit
import SwiftUI

/// A field that records a new launcher hotkey: click it, press the keys.
/// Esc while recording keeps the old hotkey.
struct HotkeyRecorder: View {
    static let conflict = "This key combination is used by another app. Choose a different one."
    private var hotkeys = HotkeyCenter.shared
    @State private var recording = false
    @State private var error: String?
    @State private var monitor: Any?

    var body: some View {
        LabeledContent("Launcher hotkey") {
            VStack(alignment: .trailing, spacing: Space.xs) {
                Button(recording ? "Press a key combination" : hotkeys.display) {
                    recording ? stop() : start()
                }
                .frame(minWidth: 160)
                .accessibilityLabel("Launcher hotkey, \(hotkeys.spoken)")
                .help("Click, then press the new key combination. Esc keeps the current one.")
                if let error {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        error = nil
        recording = true
        hotkeys.suspend()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 53, flags.isEmpty {
                stop()
                return nil
            }
            let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: HotkeyCenter.modifiers(from: flags))
            // Without ⌃, ⌥ or ⌘ the key would eat normal typing; keep listening.
            guard combo.isValid else { return nil }
            let name = HotkeyCenter.name(for: combo.keyCode, characters: event.charactersIgnoringModifiers)
            if !hotkeys.change(to: combo, keyName: name) { error = Self.conflict }
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        hotkeys.resume()
    }
}
