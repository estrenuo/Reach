import AppKit
import ReachKit
import SwiftUI

/// The selected workflow: its name, author and version, an on/off switch,
/// and what it adds to the launcher.
struct WorkflowDetail: View {
    let workflow: Workflow
    private var library = WorkflowLibrary.shared

    init(workflow: Workflow) {
        self.workflow = workflow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(Space.margin)
                .gridArea("workflow-header")
            Divider()
            Form {
                Section("Keywords") {
                    if workflow.scriptFilters.isEmpty {
                        Text("This workflow has no script filter, so it adds no keyword to the launcher.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(workflow.scriptFilters, id: \.uid) { filter in
                        LabeledContent {
                            Text(filter.keyword).monospaced()
                        } label: {
                            Text(filter.placeholder)
                            if !filter.subtext.isEmpty { Text(filter.subtext) }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Space.md) {
            WorkflowIcon(workflow: workflow, size: 48)
                .gridProbe("workflow-icon", area: "workflow-header", edge: nil)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(workflow.name)
                    .font(.title2.bold())
                Text(byline)
                    .foregroundStyle(.secondary)
                if !workflow.description.isEmpty {
                    Text(workflow.description)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .gridProbe("workflow-title", area: "workflow-header", edge: nil)
            Spacer()
            if !workflow.settings.isEmpty {
                Button("Configure Workflow…") { library.configuring = workflow }
                    .help("Fill in the settings this workflow asks for")
            }
            Toggle("On", isOn: Binding(get: { !workflow.disabled }, set: { library.setEnabled($0, workflow) }))
                .toggleStyle(.switch)
                .help(workflow.disabled ? "Turn the workflow on: its keywords work again" : "Turn the workflow off: its keywords stop working")
        }
    }

    private var byline: String {
        var parts: [String] = []
        if !workflow.author.isEmpty { parts.append("by \(workflow.author)") }
        if !workflow.version.isEmpty { parts.append("version \(workflow.version)") }
        return parts.isEmpty ? workflow.id : parts.joined(separator: " · ")
    }
}
