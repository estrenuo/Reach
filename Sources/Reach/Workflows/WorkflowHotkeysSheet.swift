import AppKit
import ReachKit
import SwiftUI

/// Hotkeys… (S-049): a key combination for each of the workflow's Hotkey
/// triggers. Alfred leaves them out of an exported workflow, so they start
/// empty. A change takes effect at once.
struct WorkflowHotkeysSheet: View {
    let workflow: Workflow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    ForEach(workflow.hotkeys) { hotkey in
                        WorkflowHotkeyRow(workflow: workflow, hotkey: hotkey)
                    }
                } header: {
                    Text("Hotkeys of “\(workflow.name)”")
                } footer: {
                    Text("Alfred does not export hotkeys, so set the ones you use. A hotkey Reach or another workflow already has stays off.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .fitsContent(max: 480)
            .frame(width: 520)
            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(Space.margin)
        }
        .noInitialFocus()
    }
}

/// One trigger: what it does and what it passes, its combination, and why it is off.
private struct WorkflowHotkeyRow: View {
    let workflow: Workflow
    let hotkey: WorkflowHotkey
    private var hotkeys = WorkflowHotkeys.shared
    @State private var recording = false
    @State private var monitor: Any?

    init(workflow: Workflow, hotkey: WorkflowHotkey) {
        self.workflow = workflow
        self.hotkey = hotkey
    }

    private var binding: WorkflowHotkeys.Binding? { hotkeys.binding(workflow, hotkey) }

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: Space.xs) {
                HStack(spacing: Space.sm) {
                    Button(recording ? "Press a key combination" : binding?.display ?? "Record Hotkey") {
                        recording ? stop() : start()
                    }
                    .frame(minWidth: 160)
                    .help("Click, then press the key combination. Esc keeps the current one.")
                    if binding != nil {
                        Button("Clear", systemImage: "xmark.circle.fill") {
                            hotkeys.set(nil, for: workflow, uid: hotkey.uid)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help("Remove this hotkey")
                    }
                }
                if let problem = hotkeys.problems[WorkflowHotkeys.key(workflow, hotkey.uid)] {
                    Text(problem)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        } label: {
            Text(workflow.label(forHotkey: hotkey.uid))
            Text(passes)
        }
        .onDisappear { stop() }
    }

    private var passes: String {
        switch hotkey.argument {
        case .none: hotkey.showsLauncher ? "Shows the launcher" : "Runs without text"
        case .selection: "Passes the selected text or files"
        case .clipboard: "Passes the clipboard's text"
        case .text(let text): "Passes “\(text)”"
        case .other: "Runs without text: Reach does not pass this argument yet"
        }
    }

    private func start() {
        recording = true
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
            hotkeys.set(.init(combo: combo, keyName: name), for: workflow, uid: hotkey.uid)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}
