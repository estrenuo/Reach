import ReachKit
import SwiftUI

/// Workflow Info… (S-046): the About text and version, the README, and the
/// environment variables, one tab each. Save writes them to info.plist.
struct WorkflowInfoSheet: View {
    let workflow: Workflow
    @State private var info: WorkflowInfo
    @State private var tab = Tab.about
    @Environment(\.dismiss) private var dismiss
    private var library = WorkflowLibrary.shared

    enum Tab: Hashable { case about, readme, variables }

    init(workflow: Workflow) {
        self.workflow = workflow
        _info = State(initialValue: WorkflowInfo(workflow))
        _tab = State(initialValue: WorkflowLibrary.shared.infoTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $tab) {
                Text("About").tag(Tab.about)
                Text("README").tag(Tab.readme)
                Text("Variables").tag(Tab.variables)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.top, Space.margin)
            Group {
                switch tab {
                case .about: about
                case .readme: readme
                case .variables: WorkflowVariablesTab(variables: $info.variables)
                }
            }
            .frame(width: 560, height: 360)
            Divider()
            HStack(alignment: .firstTextBaseline) {
                if let problem = info.problems.first {
                    Label(problem, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    library.saveInfo(info, for: workflow)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!info.problems.isEmpty || info.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(Space.margin)
        }
        .noInitialFocus()
    }

    private var about: some View {
        Form {
            TextField("Name", text: $info.name)
            TextField("Author", text: $info.author, prompt: Text("Your name"))
            TextField("Version", text: $info.version, prompt: Text("1.0"))
            TextField("Bundle ID", text: $info.bundleID, prompt: Text("com.example.workflow"))
            TextField("Website", text: $info.webAddress, prompt: Text("https://"))
            TextField("Description", text: $info.description, prompt: Text("What it does, in one line"), axis: .vertical)
                .lineLimit(2...3)
        }
        .formStyle(.grouped)
    }

    private var readme: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            TextEditor(text: $info.readme)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(Space.xs)
                .background(.background, in: RoundedRectangle(cornerRadius: Radius.row))
            Text(verbatim: "Markdown: **bold**, *italic*, `code` and [links](https://…). Configure Workflow… shows it next to the settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Space.margin)
    }
}

/// The variables as a table of name, value and Don't Export, with + and − below.
private struct WorkflowVariablesTab: View {
    @Binding var variables: [WorkflowVariable]
    @State private var selection: Set<WorkflowVariable.ID> = []

    var body: some View {
        if variables.isEmpty {
            ContentUnavailableView {
                Label("No Variables", systemImage: "list.bullet.rectangle")
            } description: {
                Text("Scripts get each variable by its name, such as $api_key.")
            } actions: {
                Button("Add Variable", systemImage: "plus", action: add)
            }
        } else {
            VStack(spacing: 0) {
                Table($variables, selection: $selection) {
                    TableColumn("Name") { $variable in
                        TextField("Name", text: $variable.name, prompt: Text("name"))
                            .labelsHidden()
                    }
                    TableColumn("Value") { $variable in
                        TextField("Value", text: $variable.value, prompt: Text("value"))
                            .labelsHidden()
                    }
                    TableColumn("Don't Export") { $variable in
                        Toggle("Don't Export", isOn: $variable.dontExport)
                            .labelsHidden()
                            .help("Leave the value out when the workflow is exported, for a key or password")
                    }
                    .width(88)
                }
                Divider()
                HStack(spacing: 0) {
                    Button("Add Variable", systemImage: "plus", action: add)
                    Button("Remove Variable", systemImage: "minus") {
                        variables.removeAll { selection.contains($0.id) }
                        selection = []
                    }
                    .disabled(selection.isEmpty)
                    Spacer()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .padding(Space.xs)
            }
            .padding(Space.margin)
        }
    }

    private func add() {
        let variable = WorkflowVariable(name: "", value: "")
        variables.append(variable)
        selection = [variable.id]
    }
}
