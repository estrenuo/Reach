import AppKit
import ReachKit

/// Watches for ⌘C pressed twice in any app (S-028), only while Append is on.
/// A global monitor sees keys without taking them: the copy still happens.
/// It needs Accessibility; it looks at ⌘C only and keeps nothing else.
final class DoubleCopyWatcher {
    let history: ClipboardHistory
    private var monitor: Any?
    private var tap = ClipboardMerge.DoubleTap()

    init(history: ClipboardHistory) {
        self.history = history
    }

    var isWatching: Bool { monitor != nil }

    /// Starts or stops watching to match the settings, now and whenever they change.
    func follow() {
        let settings = history.settings
        withObservationTracking {
            update(on: settings.canAppend && settings.appendsOnDoubleCopy)
        } onChange: { [weak self] in
            DispatchQueue.main.async { self?.follow() }
        }
    }

    private func update(on: Bool) {
        if on, monitor == nil {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                MainActor.assumeIsolated { self?.handle(event) }
            }
        } else if !on, let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        // Reach's own ⌘C, for the selection hotkey, is not a press.
        if event.cgEvent?.getIntegerValueField(.eventSourceUserData) == Paster.marker { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.type == .flagsChanged {
            if !flags.contains(.command) { tap.released() }
            return
        }
        guard event.keyCode == 8, flags.subtracting([.capsLock, .function, .numericPad]) == .command, !event.isARepeat else { return }
        guard tap.pressed(at: event.timestamp) else { return }
        // Give the app a moment to put the second copy on the pasteboard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.history.appendLatest()
        }
    }
}
