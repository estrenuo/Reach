import ReachKit
import SwiftUI

/// Configure Object… (S-064): the settings of one object on the canvas, one
/// field per key of its `config`. Save writes them into info.plist; keys the
/// sheet does not show stay as they are. ⌘Z after Save puts the old ones back.
struct WorkflowObjectSheet: View {
    let workflow: Workflow
    let object: WorkflowObject
    @State private var values: [String: PlistValue]
    /// The JSON typed in list and dictionary fields, read when Save is pressed.
    @State private var json: [String: String]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undo
    private var library = WorkflowLibrary.shared
    private let fields: [WorkflowField]

    init(workflow: Workflow, object: WorkflowObject) {
        self.workflow = workflow
        self.object = object
        let values = WorkflowForm.values(object)
        let fields = WorkflowForm.fields(object.type)
        self.fields = fields
        _values = State(initialValue: values)
        _json = State(initialValue: Dictionary(uniqueKeysWithValues: fields.filter { $0.kind == .structured }
            .map { ($0.key, WorkflowForm.json(values[$0.key] ?? .array([]))) }))
    }

    /// The list and dictionary fields whose JSON does not read.
    private var invalid: Set<String> {
        Set(fields.filter { field in
            field.kind == .structured && (try? WorkflowForm.value(json: json[field.key] ?? "", like: values[field.key] ?? .array([]),
                                                                    label: field.label)) == nil
        }.map(\.key))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    ForEach(fields) { field in
                        row(field)
                    }
                } header: {
                    Text("Configure \(object.kindName)")
                } footer: {
                    Text("Saved in the workflow's info.plist, so Alfred reads it too.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .fitsContent(max: 560)
            .frame(width: 520)
            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!invalid.isEmpty)
            }
            .padding(Space.margin)
        }
        .noInitialFocus()
    }

    private func save() {
        var saved = values
        for field in fields where field.kind == .structured {
            if let value = try? WorkflowForm.value(json: json[field.key] ?? "", like: values[field.key] ?? .array([]), label: field.label) {
                saved[field.key] = value
            }
        }
        library.configure(object.uid, values: saved, in: workflow, undo: undo)
        dismiss()
    }

    @ViewBuilder
    private func row(_ field: WorkflowField) -> some View {
        switch field.kind {
        case .text:
            TextField(field.label, text: text(field.key))
        case .lines(let code):
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(field.label)
                TextEditor(text: text(field.key))
                    .font(code ? .body.monospaced() : .body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: code ? 160 : 60)
                    .accessibilityLabel(field.label)
            }
        case .toggle:
            Toggle(field.label, isOn: Binding(get: { values[field.key]?.bool ?? false }, set: { values[field.key] = .bool($0) }))
        case .number:
            TextField(field.label, value: Binding(get: { values[field.key]?.int ?? 0 }, set: { values[field.key] = .int($0) }), format: .number)
        case .choice(let choices):
            Picker(field.label, selection: Binding(get: { values[field.key]?.int ?? choices.first?.value ?? 0 }, set: { values[field.key] = .int($0) })) {
                ForEach(choices, id: \.value) { choice in
                    Text(choice.title).tag(choice.value)
                }
                // A value Alfred wrote that the sheet has no name for stays choosable.
                if let current = values[field.key]?.int, !choices.contains(where: { $0.value == current }) {
                    Text("Other (\(current))").tag(current)
                }
            }
        case .structured:
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(field.label)
                VStack(alignment: .leading, spacing: Space.xs) {
                    TextEditor(text: Binding(get: { json[field.key] ?? "" }, set: { json[field.key] = $0 }))
                        .font(.body.monospaced())
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .accessibilityLabel(field.label)
                    if invalid.contains(field.key) {
                        Label("\(field.label) is not valid JSON of the right shape.", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("JSON").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func text(_ key: String) -> Binding<String> {
        Binding(get: { values[key]?.string ?? "" }, set: { values[key] = .string($0) })
    }
}
