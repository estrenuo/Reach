import AppKit
import ReachKit
import SwiftUI

/// The debugger under the canvas (S-045): each run of the workflow's scripts,
/// timestamped, with what they printed and what went wrong.
struct WorkflowDebugger: View {
    let workflow: Workflow
    private var library = WorkflowLibrary.shared

    init(workflow: Workflow) {
        self.workflow = workflow
    }

    private var entries: [WorkflowLogEntry] {
        library.log.shown(library.logLevel).filter { $0.workflow == workflow.name }
    }

    var body: some View {
        @Bindable var library = library
        VStack(spacing: 0) {
            HStack(spacing: Space.sm) {
                Picker("Log Level", selection: $library.logLevel) {
                    ForEach(WorkflowLogLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .help("Show every run, or only the errors")
                .gridProbe("debugger-level", area: "workflow-debugger", edge: "leading")
                Spacer()
                Button("Copy", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(library.selectedLogText, forType: .string)
                }
                .disabled(entries.isEmpty)
                .help("Copy the lines shown to the clipboard")
                Button("Clear", systemImage: "trash") { library.log.clear() }
                    .disabled(library.log.entries.isEmpty)
                    .help("Remove every line from the debugger")
            }
            .padding(.horizontal, Space.margin)
            .padding(.vertical, Space.sm)
            .gridArea("workflow-debugger")
            Divider()
            if entries.isEmpty {
                ContentUnavailableView("No Runs Yet", systemImage: "ladybug",
                                       description: Text("Type this workflow's keyword in the launcher. Each run shows here."))
            } else {
                ScrollViewReader { reader in
                    List(entries) { entry in
                        Line(entry: entry)
                            .id(entry.id)
                            .listRowInsets(EdgeInsets(top: Space.xs, leading: Space.margin, bottom: Space.xs, trailing: Space.margin))
                    }
                    .listStyle(.plain)
                    .onAppear { reader.scrollTo(entries.last?.id, anchor: .bottom) }
                    .onChange(of: entries.last?.id) { _, last in reader.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }
}

/// One log line: its time, then the text; errors in red.
private struct Line: View {
    let entry: WorkflowLogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            Text(WorkflowLog.time(entry.date))
                .foregroundStyle(.secondary)
            Text(entry.text)
                .foregroundStyle(entry.kind == .error ? AnyShapeStyle(.red) : entry.kind == .ran ? AnyShapeStyle(.primary)
                                 : AnyShapeStyle(.secondary))
                .fontWeight(entry.kind == .ran ? .medium : .regular)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.callout, design: .monospaced))
    }
}
