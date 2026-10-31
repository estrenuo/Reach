import AppKit
import ReachKit

/// The workflows' Hotkey triggers (S-049). Alfred leaves the key combination
/// out of an exported workflow, so people set it in Hotkeys…; Reach keeps it
/// in its settings, by workflow folder and trigger. Each enabled workflow's
/// hotkeys are registered again whenever the library is read, except one
/// that is Reach's own or another workflow's: that one is skipped and logged.
@Observable
final class WorkflowHotkeys {
    static let shared = WorkflowHotkeys()
    private static let settingsKey = "workflow.hotkeys"

    struct Binding: Codable, Equatable {
        var combo: KeyCombo
        var keyName: String
        var display: String { combo.display(key: keyName) }
    }

    /// The combinations people set, by `workflow-folder/trigger-uid`.
    private(set) var bindings: [String: Binding]
    /// Why a hotkey with a combination is not active, by the same key.
    private(set) var problems: [String: String] = [:]
    /// Runs a pressed hotkey; the launcher model sets it.
    @ObservationIgnored var run: @MainActor (Workflow, WorkflowHotkey) -> Void = { _, _ in }
    /// False in test runs: the plan is made, but no real key is taken.
    @ObservationIgnored var registers = true
    @ObservationIgnored private var registered: [UInt32: String] = [:]
    @ObservationIgnored private var applied: [WorkflowHotkeyPlan.Entry]?
    private let library: WorkflowLibrary

    init(library: WorkflowLibrary = .shared) {
        self.library = library
        let data = Store.settings.data(forKey: Self.settingsKey)
        bindings = data.flatMap { try? JSONDecoder().decode([String: Binding].self, from: $0) } ?? [:]
    }

    static func key(_ workflow: Workflow, _ uid: String) -> String { workflow.id + "/" + uid }

    /// The combination a trigger has: the one people set, else Alfred's own.
    func binding(_ workflow: Workflow, _ hotkey: WorkflowHotkey) -> Binding? {
        bindings[Self.key(workflow, hotkey.uid)] ?? hotkey.combo.map { Binding(combo: $0, keyName: hotkey.keyName) }
    }

    /// Sets or clears a trigger's combination, and registers the hotkeys again.
    func set(_ binding: Binding?, for workflow: Workflow, uid: String) {
        bindings[Self.key(workflow, uid)] = binding
        Store.settings.set(try? JSONEncoder().encode(bindings), forKey: Self.settingsKey)
        apply()
    }

    /// Registers the enabled workflows' hotkeys; unchanged ones stay as they are.
    func apply() {
        var wanted: [WorkflowHotkeyPlan.Entry] = []
        for workflow in library.workflows where !workflow.disabled {
            for hotkey in workflow.hotkeys {
                guard let binding = binding(workflow, hotkey) else { continue }
                wanted.append(.init(workflow: workflow.name, uid: Self.key(workflow, hotkey.uid), combo: binding.combo))
            }
        }
        guard wanted != applied else { return }
        applied = wanted
        HotkeyCenter.shared.unregisterWorkflows()
        registered = [:]
        problems = [:]
        let plan = WorkflowHotkeyPlan.plan(wanted, reserved: HotkeyCenter.shared.reserved)
        for (entry, reason) in plan.skipped {
            skip(entry, because: reason)
        }
        var id = HotkeyCenter.firstWorkflowID
        for entry in plan.use {
            if registers, !HotkeyCenter.shared.registerWorkflow(entry.combo, id: id) {
                skip(entry, because: "another app uses it")
                continue
            }
            registered[id] = entry.uid
            id += 1
        }
    }

    /// The registered hotkey with this id was pressed.
    func pressed(_ id: UInt32) {
        if let key = registered[id] { press(key) }
    }

    /// Runs the trigger with this key, when its related apps allow it. The
    /// self-test calls this instead of pressing a real key.
    func press(_ key: String) {
        guard let slash = key.lastIndex(of: "/"),
              let workflow = library.workflow(String(key[..<slash])), !workflow.disabled,
              let hotkey = workflow.hotkeys.first(where: { $0.uid == key[key.index(after: slash)...] }),
              hotkey.isActive(frontApp: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) else { return }
        run(workflow, hotkey)
    }

    /// True when the trigger with this key is registered now.
    func isRegistered(_ key: String) -> Bool { registered.values.contains(key) }

    private func skip(_ entry: WorkflowHotkeyPlan.Entry, because reason: String) {
        problems[entry.uid] = "Not active: \(reason)."
        library.log.failed(workflow: entry.workflow, text: "A hotkey was not turned on: \(reason).")
    }
}
