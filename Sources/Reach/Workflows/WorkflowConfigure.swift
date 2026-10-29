import AppKit
import ReachKit
import SwiftUI

/// Configure Workflow… (S-043): the fields the workflow asks for on the left,
/// its README on the right. Save keeps the values in the folder's prefs.plist;
/// scripts get them as environment variables.
struct WorkflowConfigureSheet: View {
    let workflow: Workflow
    @State private var values: [String: String]
    @Environment(\.dismiss) private var dismiss
    private var library = WorkflowLibrary.shared

    init(workflow: Workflow) {
        self.workflow = workflow
        _values = State(initialValue: WorkflowConfiguration.resolved(workflow.settings, saved: workflow.configuration))
    }

    private var missing: Set<String> { Set(WorkflowConfiguration.missing(workflow.settings, values: values).map(\.variable)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Form {
                    Section {
                        ForEach(workflow.settings) { setting in
                            field(setting)
                        }
                    } header: {
                        Text("Configure “\(workflow.name)”")
                    } footer: {
                        Text("Scripts get each value as an environment variable.")
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
                .fitsContent(max: 480)
                .frame(width: 420)
                Divider()
                ReadmeView(text: workflow.readme)
                    .frame(width: 320)
                    .frame(maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                Button("Reset to Defaults") {
                    values = WorkflowConfiguration.resolved(workflow.settings, saved: [:])
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    library.saveConfiguration(values, for: workflow)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!missing.isEmpty)
            }
            .padding(Space.margin)
        }
        .noInitialFocus()
    }

    @ViewBuilder
    private func field(_ setting: WorkflowSetting) -> some View {
        let value = Binding(get: { values[setting.variable] ?? "" }, set: { values[setting.variable] = $0 })
        VStack(alignment: .leading, spacing: Space.xs) {
            switch setting.kind {
            case .textfield:
                TextField(setting.label, text: value, prompt: Text(setting.placeholder))
            case .textarea:
                LabeledContent(setting.label) {
                    TextEditor(text: value)
                        .font(.body)
                        .frame(minHeight: 60)
                }
            case .checkbox:
                LabeledContent(setting.label) {
                    Toggle(setting.text.isEmpty ? setting.label : setting.text,
                           isOn: Binding(get: { value.wrappedValue == "1" }, set: { value.wrappedValue = $0 ? "1" : "0" }))
                        .toggleStyle(.checkbox)
                }
            case .popupbutton:
                Picker(setting.label, selection: value) {
                    ForEach(setting.options, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
            case .filepicker:
                LabeledContent(setting.label) {
                    HStack {
                        Text(value.wrappedValue.isEmpty ? "None" : (value.wrappedValue as NSString).abbreviatingWithTildeInPath)
                            .foregroundStyle(value.wrappedValue.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…") {
                            if let path = Self.choosePath() { value.wrappedValue = path }
                        }
                    }
                }
            }
            if missing.contains(setting.variable) {
                Label("\(setting.label) is required.", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !setting.description.isEmpty {
                Text(setting.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static func choosePath() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}

/// A workflow's README, its Markdown rendered.
struct ReadmeView: View {
    let text: String

    var body: some View {
        if text.isEmpty {
            ContentUnavailableView("No README", systemImage: "doc.text", description: Text("The workflow's author wrote no README."))
        } else {
            ScrollView {
                Text(Self.render(text))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.margin)
            }
        }
    }

    /// Markdown with its paragraphs kept.
    static func render(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
