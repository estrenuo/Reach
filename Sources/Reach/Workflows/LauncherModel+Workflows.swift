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
        if !steps.contains(where: { if case .show = $0 { true } else { false } }) { onHide() }
        return true
    }

    /// Runs the steps in order. A script runs in the background and its
    /// output goes on to the objects after it, at most five scripts deep.
    private func runSteps(_ steps: [WorkflowStep], in workflow: Workflow, depth: Int = 0) -> Bool {
        var worked = true
        for step in steps {
            switch step {
            case .open(let text):
                worked = openWorkflowTarget(text) && worked
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
