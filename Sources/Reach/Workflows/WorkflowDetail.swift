import AppKit
import ReachKit
import SwiftUI

/// The selected workflow: its name, author and version, an on/off switch,
/// its objects on a canvas (S-044), and the debugger under it (S-045).
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
            WorkflowCanvasView(workflow: workflow)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if library.debugging {
                Divider()
                WorkflowDebugger(workflow: workflow)
                    .frame(height: 220)
            }
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
            Button {
                library.debugging.toggle()
            } label: {
                Label(library.debugging ? "Hide Debugger" : "Debugger", systemImage: "ladybug")
            }
            .help("Show each run of this workflow's scripts, with their output and errors")
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
