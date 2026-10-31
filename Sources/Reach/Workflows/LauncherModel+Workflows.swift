import Foundation
import ReachKit

/// The launcher's side of workflows (S-041): Return, or ⌃↩ ⌥↩ ⌘↩, on a
/// script filter row runs the objects connected to that filter.
extension LauncherModel {
    /// Runs `run`, with `modifier` held. False when the row has nothing for
    /// that modifier, so the key keeps its own meaning.
    @discardableResult
    func runWorkflow(_ run: WorkflowRun, result: LaunchResult, modifier: ReturnModifier? = nil) -> Bool {
        guard let workflow = workflows.library.workflow(run.workflow) else {
            if modifier != nil { return false }
            showError("This workflow is no longer installed.", on: result.id)
            return true
        }
        var argument = run.argument
        var variables = run.variables
        var valid = run.valid
        if let modifier {
            let mod = run.mods[modifier.modName]
            let hasLine = workflow.connections[run.filter]?.contains { $0.modifiers == modifier.connectionFlag } ?? false
            guard mod != nil || hasLine else { return false }
            if let mod {
                valid = mod.valid
                argument = mod.arg?.first ?? argument
                variables.merge(mod.variables) { _, new in new }
            }
        }
        guard valid else { return true }
        let all = workflow.variables.merging(variables) { _, new in new }
        let steps = workflow.steps(after: run.filter, argument: argument, modifiers: modifier?.connectionFlag ?? 0,
                                   variables: all, environment: workflows.library.environment(for: workflow, variables: variables))
        guard !steps.isEmpty else {
            showError("Nothing in \(workflow.name) uses this result.", on: result.id)
            return true
        }
        let skipped = steps.compactMap { if case .unsupported(let kind) = $0 { kind } else { nil } }
        if skipped.count == steps.count {
            skipped.forEach { workflows.library.skipped(workflow, kind: $0) }
            showError("Reach does not run \(skipped[0]) yet.", on: result.id)
            return true
        }
        guard runSteps(steps, in: workflow) else {
            showError("Unable to open \(argument).", on: result.id)
            return true
        }
        onUsed(.workflows)
        if !steps.contains(where: Self.showsLauncher) { onHide() }
        return true
    }

    /// A workflow's hotkey was pressed (S-049): reads the argument it asks
    /// for, then shows the launcher with it or runs the objects connected to it.
    func runHotkey(_ hotkey: WorkflowHotkey, in workflow: Workflow) async {
        let library = workflows.library
        var selection: String?
        if hotkey.argument == .selection {
            switch await readSelection() {
            case .text(let text, _): selection = text
            case .files(let urls): selection = urls.map(\.path).joined(separator: "\t")
            case .nothing, .noAccess: selection = nil
            }
        }
        let (text, unsupported) = hotkey.text(selection: selection,
                                              clipboard: hotkey.argument == .clipboard ? readClipboard() : nil)
        if let unsupported {
            library.log.failed(workflow: workflow.name, text: "Reach does not pass \(unsupported) yet; the hotkey ran without it.")
        }
        library.log.debug(workflow: workflow.name, text: text.isEmpty ? "Hotkey ran" : "Hotkey ran with “\(text)”")
        if hotkey.showsLauncher {
            onShow()
            query = text
            return
        }
        let steps = workflow.steps(after: hotkey.uid, argument: text, variables: workflow.variables,
                                   environment: library.environment(for: workflow))
        _ = runSteps(steps, in: workflow)
        onUsed(.workflows)
    }

    enum WorkflowActionOutcome: Equatable {
        case done
        /// The workflow showed the launcher with a keyword; it stays.
        case shows
        case failed(String)
    }

    /// Runs a workflow's File Action (S-050) or Universal Action (S-052),
    /// the trigger `uid` called `title`, with the text or the paths, tab-separated.
    func runWorkflowAction(_ uid: String, title: String, in id: String, argument: String) -> WorkflowActionOutcome {
        let library = workflows.library
        guard let workflow = library.workflow(id), !workflow.disabled else { return .failed("This workflow is no longer installed.") }
        library.log.debug(workflow: workflow.name, text: "“\(title)” ran with “\(argument)”")
        let steps = workflow.steps(after: uid, argument: argument, variables: workflow.variables,
                                   environment: library.environment(for: workflow))
        guard !steps.isEmpty else { return .failed("Nothing in \(workflow.name) uses this action.") }
        let skipped = steps.compactMap { if case .unsupported(let kind) = $0 { kind } else { nil } }
        if skipped.count == steps.count {
            skipped.forEach { library.skipped(workflow, kind: $0) }
            return .failed("Reach does not run \(skipped[0]) yet.")
        }
        guard runSteps(steps, in: workflow) else { return .failed("Unable to run “\(title)”.") }
        onUsed(.workflows)
        return steps.contains(where: Self.showsLauncher) ? .shows : .done
    }

    /// A step that leaves the launcher open: a keyword shown again, a Grid View (S-053),
    /// or the action panel (S-054).
    static func showsLauncher(_ step: WorkflowStep) -> Bool {
        switch step {
        case .show, .grid, .actions: true
        default: false
        }
    }

    /// Runs the steps in order. A script runs in the background and its
    /// output goes on to the objects after it, at most five scripts deep.
    private func runSteps(_ steps: [WorkflowStep], in workflow: Workflow, depth: Int = 0) -> Bool {
        var worked = true
        for step in steps {
            switch step {
            case .open(let text):
                worked = openWorkflowTarget(text) && worked
            case .keys(let keys):
                if !pressKeys(keys) {
                    workflows.library.log.failed(workflow: workflow.name, text: "Reach could not press the keys: "
                        + "allow it in System Settings > Privacy & Security > Accessibility.")
                }
            case .terminal(let path):
                worked = openTerminal(URL(fileURLWithPath: (path as NSString).expandingTildeInPath)) && worked
            case .reveal(let path):
                worked = perform(.action(.reveal), [URL(fileURLWithPath: (path as NSString).expandingTildeInPath)]) && worked
            case .trash(let path):
                worked = perform(.action(.trash), [URL(fileURLWithPath: (path as NSString).expandingTildeInPath)]) && worked
            case .notify(let title, let text):
                notify(workflow, title, text)
            case .sound(let sound):
                playSound(sound)
            case .debug(let text, let clear):
                workflows.library.log.debug(workflow: workflow.name, text: text, clear: clear)
            case .copy(let text):
                copier(text)
            case .largeType(let text):
                largeType(text)
            case .run(let command, let then, let variables):
                guard depth < 5 else { continue }
                Task { [weak self] in
                    guard let self else { return }
                    let result = await self.workflows.run(command)
                    self.workflows.onAction(workflow, command, result)
                    let next = workflow.steps(after: then, argument: result.text, variables: variables,
                                              environment: command.environment)
                    _ = self.runSteps(next, in: workflow, depth: depth + 1)
                }
            case .dialog(let title, let text, let buttons):
                showDialog(title, text, buttons)
            case .wait(let seconds, let then, let argument, let variables, let environment):
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(seconds))
                    guard let self else { return }
                    _ = self.runSteps(workflow.steps(after: then, argument: argument, variables: variables, environment: environment),
                                      in: workflow, depth: depth)
                }
            case .actions(let text):
                onShow()
                let path = (text as NSString).expandingTildeInPath
                showActions(for: path.hasPrefix("/") && FileManager.default.fileExists(atPath: path)
                    ? .files([URL(fileURLWithPath: path)]) : .text(text, source: workflow.name))
            case .currentTab(let then, let allowEmpty, let variables, let environment):
                guard depth < 5 else { continue }
                Task { [weak self] in
                    guard let self else { return }
                    let url: String
                    switch await self.readCurrentTab() {
                    case .success(let found): url = found ?? ""
                    case .failure(let problem):
                        self.workflows.library.log.failed(workflow: workflow.name, text: problem.kind)
                        url = ""
                    }
                    guard !url.isEmpty || allowEmpty else { return }
                    let next = workflow.steps(after: then, argument: url, variables: variables, environment: environment)
                    _ = self.runSteps(next, in: workflow, depth: depth + 1)
                }
            case .grid(let run):
                onShow()
                workflows.forget()
                workflows.showGrid(run, in: workflow)
                if query.isEmpty { refresh() } else { query = "" }
            case .show(let text):
                onShow()
                workflows.forget()
                if query == text { refresh() } else { query = text }
            case .unsupported(let kind):
                workflows.library.skipped(workflow, kind: kind)
            }
        }
        return worked
    }

    /// A path opens the file, anything with a scheme opens as a URL.
    private func openWorkflowTarget(_ text: String) -> Bool {
        let expanded = (text as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            guard FileManager.default.fileExists(atPath: expanded) else { return false }
            return opener(URL(fileURLWithPath: expanded))
        }
        guard let url = URL(string: text), url.scheme?.isEmpty == false else { return false }
        return opener(url)
    }
}
