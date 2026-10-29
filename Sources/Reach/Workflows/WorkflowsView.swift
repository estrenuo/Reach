import AppKit
import ReachKit
import SwiftUI
import UniformTypeIdentifiers

/// The Workflows window (S-042): the installed workflows with a filter and
/// + and − below, and the selected one, or start cards when none is selected.
struct WorkflowsView: View {
    @Bindable private var library = WorkflowLibrary.shared

    var body: some View {
        NavigationSplitView {
            WorkflowList()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let workflow = library.selected {
                WorkflowDetail(workflow: workflow)
            } else {
                WorkflowStart()
            }
        }
        .navigationTitle(library.selected?.name ?? "Workflows")
        .frame(minWidth: 860, minHeight: 540)
        .noInitialFocus()
        .onAppear { library.reload() }
        .focusedSceneValue(\.workflowsInFront, true)
        .alert("Workflows", isPresented: Binding(get: { library.failure != nil }, set: { if !$0 { library.failure = nil } })) {
            Button("OK") { library.failure = nil }
        } message: {
            Text(library.failure ?? "")
        }
        .sheet(item: $library.configuring) { workflow in
            WorkflowConfigureSheet(workflow: workflow)
        }
        .confirmationDialog(removeTitle, isPresented: Binding(get: { library.removing != nil }, set: { if !$0 { library.removing = nil } })) {
            Button("Move to Trash", role: .destructive) {
                if let workflow = library.removing { library.remove(workflow) }
                library.removing = nil
            }
            Button("Cancel", role: .cancel) { library.removing = nil }
        } message: {
            Text("Its keywords stop working. You can put it back from the Trash.")
        }
    }

    private var removeTitle: String {
        library.removing.map { "Move “\($0.name)” to the Trash?" } ?? ""
    }

    /// The open panel for Install Workflow…: a workflow folder or an .alfredworkflow file.
    static func chooseAndInstall() {
        let panel = NSOpenPanel()
        panel.title = "Install Workflow"
        panel.prompt = "Install"
        panel.message = "Choose a workflow folder or an .alfredworkflow file."
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "alfredworkflow") ?? .zip, .folder]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        WorkflowLibrary.shared.install(from: url)
    }
}

/// The workflows by name: icon, name and author. A switched-off one is dimmed.
private struct WorkflowList: View {
    @Bindable private var library = WorkflowLibrary.shared
    @FocusState private var filtering: Bool

    var body: some View {
        List(selection: $library.selection) {
            ForEach(library.shown) { workflow in
                WorkflowRow(workflow: workflow)
                    .tag(workflow.id)
                    .contextMenu {
                        if !workflow.settings.isEmpty {
                            Button("Configure…") { library.configuring = workflow }
                        }
                        Button(workflow.disabled ? "Turn On" : "Turn Off") { library.setEnabled(workflow.disabled, workflow) }
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([workflow.folder]) }
                        Divider()
                        Button("Remove…", role: .destructive) { library.removing = workflow }
                    }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if library.workflows.isEmpty {
                ContentUnavailableView("No Workflows", systemImage: WorkflowSource.symbol,
                                       description: Text("Install one with +."))
            } else if library.shown.isEmpty {
                ContentUnavailableView.search(text: library.filter)
            }
        }
        .searchable(text: $library.filter, placement: .sidebar, prompt: "Filter Workflows")
        .searchFocused($filtering)
        .onChange(of: library.filterRequests) { filtering = true }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlusMinusBar(addHelp: "Install a workflow", removeHelp: "Move the selected workflow to the Trash",
                         canRemove: library.selected != nil,
                         add: WorkflowsView.chooseAndInstall,
                         remove: { library.removing = library.selected })
        }
    }
}

private struct WorkflowRow: View {
    let workflow: Workflow

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 0) {
                Text(workflow.name)
                Text(workflow.author.isEmpty ? (workflow.disabled ? "Off" : " ") : "by \(workflow.author)\(workflow.disabled ? " · Off" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            WorkflowIcon(workflow: workflow, size: Space.xxl)
        }
        .opacity(workflow.disabled ? 0.5 : 1)
        .accessibilityLabel(workflow.disabled ? "\(workflow.name), off" : workflow.name)
        .help(workflow.description)
    }
}

/// The workflow's icon.png, or the workflow symbol.
struct WorkflowIcon: View {
    let workflow: Workflow
    let size: CGFloat

    var body: some View {
        Group {
            if let icon = workflow.icon {
                IconCache.image(for: .image(icon.path)).resizable().scaledToFit()
            } else {
                Image(systemName: WorkflowSource.symbol)
                    .font(.system(size: size * 0.6))
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Nothing selected: what to do first, as cards.
private struct WorkflowStart: View {
    private var library = WorkflowLibrary.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            VStack(alignment: .leading, spacing: Space.sm) {
                Image(systemName: WorkflowSource.symbol)
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Workflows")
                    .font(.title2.bold())
                Text("A workflow adds keywords to the launcher. Its script answers with the rows to show.")
                    .foregroundStyle(.secondary)
            }
            .gridProbe("start-title", area: "workflows-start", edge: "leading")
            HStack(alignment: .top, spacing: Space.lg) {
                StartCard(title: "Install Workflow…", detail: "A workflow folder or an .alfredworkflow file.",
                          symbol: "square.and.arrow.down", action: WorkflowsView.chooseAndInstall)
                    .gridProbe("start-cards", area: "workflows-start", edge: "leading")
                StartCard(title: "Add Example", detail: "Hello World: type “hello” and a name.",
                          symbol: "sparkles", action: library.addExample)
                StartCard(title: "Open Workflows Folder", detail: "Copy workflow folders in here by hand.",
                          symbol: "folder", action: {
                              try? FileManager.default.createDirectory(at: library.folder, withIntermediateDirectories: true)
                              NSWorkspace.shared.open(library.folder)
                          })
            }
        }
        .padding(Space.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .gridArea("workflows-start")
    }
}

private struct StartCard: View {
    let title: String
    let detail: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Space.sm) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(height: Space.section, alignment: .leading)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.lg)
            .frame(width: 180, alignment: .topLeading)
            .frame(minHeight: 128, alignment: .topLeading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Radius.row))
            .contentShape(RoundedRectangle(cornerRadius: Radius.row))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}

/// Workflows menu items, while the Workflows window is in front.
struct WorkflowCommands: Commands {
    @FocusedValue(\.workflowsInFront) private var workflowsInFront
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(before: .windowList) {
            Button("Workflows") {
                NSApp.activate()
                openWindow(id: WorkflowLibrary.windowID)
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            Divider()
        }
        CommandMenu("Workflow") {
            let library = WorkflowLibrary.shared
            let inFront = workflowsInFront == true
            Button("Install Workflow…", action: WorkflowsView.chooseAndInstall)
                .keyboardShortcut("o")
                .disabled(!inFront)
            Button("Add Example Workflow", action: library.addExample)
                .disabled(!inFront)
            Divider()
            Button("Filter Workflows") { library.filterRequests += 1 }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(!inFront)
            Button("Configure Workflow…") { library.configuring = library.selected }
                .keyboardShortcut("e")
                .disabled(!inFront || library.selected?.settings.isEmpty != false)
            Button(library.selected?.disabled == true ? "Turn On Workflow" : "Turn Off Workflow") {
                if let workflow = library.selected { library.setEnabled(workflow.disabled, workflow) }
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .disabled(!inFront || library.selected == nil)
            Button(library.debugging ? "Hide Debugger" : "Show Debugger") { library.debugging.toggle() }
                .keyboardShortcut("d", modifiers: [.command, .option])
                .disabled(!inFront || library.selected == nil)
            Button("Show in Finder") {
                if let workflow = library.selected { NSWorkspace.shared.activateFileViewerSelecting([workflow.folder]) }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(!inFront || library.selected == nil)
            Divider()
            Button("Remove Workflow…") { library.removing = library.selected }
                .keyboardShortcut(.delete)
                .disabled(!inFront || library.selected == nil)
        }
    }
}

extension FocusedValues {
    @Entry var workflowsInFront: Bool?
}
