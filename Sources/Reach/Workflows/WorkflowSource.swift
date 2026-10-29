import Foundation
import ReachKit

/// What Return does for a workflow row: the script filter it came from and the row's argument.
struct WorkflowRun: Equatable {
    var workflow: String
    var filter: String
    var argument: String
    /// False for a row Return does nothing with (or completes, when it has an autocomplete).
    var valid = true
    var variables: [String: String] = [:]
    /// The rows for ⌃↩, ⌥↩ and ⌘↩, by the names the JSON uses (ctrl, alt, cmd).
    var mods: [String: ScriptFilterOutput.Mod] = [:]
}

extension ReturnModifier {
    /// The name in Script Filter JSON.
    var modName: String {
        switch self {
        case .control: "ctrl"
        case .option: "alt"
        case .command: "cmd"
        }
    }

    /// The key on a workflow's connection line.
    var connectionFlag: Int {
        switch self {
        case .control: WorkflowConnection.control
        case .option: WorkflowConnection.option
        case .command: WorkflowConnection.command
        }
    }
}

/// Script filters (S-041): while a workflow's keyword is typed, its script
/// runs with the text after it, and the rows it prints replace a "please
/// wait" row. A new query stops the script that is running.
final class WorkflowSource: ResultSource {
    let library: WorkflowLibrary
    /// The query as typed, since a trailing space after the keyword matters. Set by the model.
    var typed = ""
    /// Runs a script. The self-test swaps in a fake that answers when it says so.
    var run: (ScriptCommand) async -> ScriptResult = { await ScriptRunner.run($0) }
    /// Called after each script filter run, for the debugger (S-045).
    var onRun: (Workflow, ScriptFilter, String, ScriptResult) -> Void = { _, _, _, _ in }
    /// Called after a Run Script object ran, for the debugger (S-045).
    var onAction: (Workflow, ScriptCommand, ScriptResult) -> Void = { _, _, _ in }

    private var task: Task<Void, Never>?
    /// Output of filters that let Reach filter: the script runs once while the launcher is open.
    private var cached: [String: ScriptFilterOutput] = [:]

    init(library: WorkflowLibrary = .shared) {
        self.library = library
    }

    static let symbol = "flowchart"

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        switch query {
        case .path, .shell: return []
        default: break
        }
        var rows: [Scored] = []
        var runs: [(workflow: Workflow, filter: ScriptFilter, text: String)] = []
        for workflow in library.workflows where !workflow.disabled {
            for filter in workflow.scriptFilters {
                switch filter.match(typed) {
                case .keyword:
                    rows.append(Scored(result: keywordRow(filter, in: workflow, completes: true),
                                       score: Matcher.score(query: typed, title: filter.keyword) ?? 500))
                case .needsText:
                    let done = typed.lowercased() == filter.completion.lowercased()
                    rows.append(Scored(result: keywordRow(filter, in: workflow, completes: !done), score: 1000))
                case .run(let text):
                    runs.append((workflow, filter, text))
                case nil:
                    continue
                }
            }
        }
        guard !runs.isEmpty else { return rows }

        // One row per filter until its script answers, then its own rows.
        var answers: [[Scored]?] = Array(repeating: nil, count: runs.count)
        func current() -> [Scored] {
            rows + runs.indices.flatMap { index in
                answers[index] ?? [Scored(result: waitingRow(runs[index].filter, in: runs[index].workflow), score: 0)]
            }
        }
        task = Task { [weak self] in
            for (index, run) in runs.enumerated() {
                guard let self, !Task.isCancelled else { return }
                let rows = await self.rows(for: run.filter, in: run.workflow, text: run.text)
                guard !Task.isCancelled else { return }
                answers[index] = rows
                later(current())
            }
        }
        return current()
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    /// The launcher opened again: filters that Reach filters run their script again.
    func forget() {
        cached = [:]
    }

    private func rows(for filter: ScriptFilter, in workflow: Workflow, text: String) async -> [Scored] {
        let key = workflow.id + "/" + filter.uid
        let output: ScriptFilterOutput
        if filter.filtersResults, let saved = cached[key] {
            output = saved
        } else {
            let environment = library.environment(for: workflow)
            guard let command = filter.script.command(query: filter.filtersResults ? "" : text, folder: workflow.folder,
                                                      environment: environment) else {
                return [failureRow(filter, in: workflow, "Reach does not run this script language.")]
            }
            let result = await run(command)
            guard !Task.isCancelled else { return [] }
            onRun(workflow, filter, text, result)
            if let failure = result.failure { return [failureRow(filter, in: workflow, failure)] }
            do {
                output = try ScriptFilterOutput.parse(result.output)
            } catch {
                let reason = result.status != 0 && !result.errors.isEmpty ? result.errors : error.localizedDescription
                return [failureRow(filter, in: workflow, reason)]
            }
            if filter.filtersResults { cached[key] = output }
        }
        let items = filter.filtersResults ? output.filtered(by: text) : output.items
        return items.enumerated().map { index, item in
            Scored(result: row(item, index: index, filter: filter, in: workflow, variables: output.variables), score: 0)
        }
    }

    private func row(_ item: ScriptFilterOutput.Item, index: Int, filter: ScriptFilter, in workflow: Workflow,
                     variables: [String: String]) -> LaunchResult {
        var result = LaunchResult(id: "workflow:\(workflow.id):\(filter.uid):\(index):\(item.uid ?? "")",
                                  title: item.title, subtitle: item.subtitle, icon: icon(item.icon, in: workflow))
        result.kindLabel = workflow.name
        result.isPinned = true
        result.workflow = WorkflowRun(workflow: workflow.id, filter: filter.uid, argument: item.argument, valid: item.valid,
                                      variables: variables.merging(item.variables) { _, new in new }, mods: item.mods)
        if !item.valid, let autocomplete = item.autocomplete {
            result.completes = filter.completion + autocomplete
        }
        return result
    }

    /// The row for a keyword typed in part, or typed with the text still missing.
    private func keywordRow(_ filter: ScriptFilter, in workflow: Workflow, completes: Bool) -> LaunchResult {
        var result = LaunchResult(id: "workflow:\(workflow.id):\(filter.uid)", title: filter.placeholder,
                                  subtitle: filter.subtext.isEmpty ? workflow.name : filter.subtext, icon: icon(nil, in: workflow))
        result.kindLabel = workflow.name
        if completes { result.completes = filter.completion }
        return result
    }

    /// The row while the script runs: the placeholder title with "please wait" under it.
    private func waitingRow(_ filter: ScriptFilter, in workflow: Workflow) -> LaunchResult {
        var result = LaunchResult(id: "workflow:\(workflow.id):\(filter.uid):waiting", title: filter.placeholder,
                                  subtitle: filter.waitingText, icon: icon(nil, in: workflow))
        result.kindLabel = workflow.name
        return result
    }

    private func failureRow(_ filter: ScriptFilter, in workflow: Workflow, _ message: String) -> Scored {
        let line = message.split(separator: "\n").first.map(String.init) ?? message
        var result = LaunchResult(id: "workflow:\(workflow.id):\(filter.uid):failed", title: filter.placeholder,
                                  subtitle: line, icon: .symbol("exclamationmark.triangle"))
        result.kindLabel = workflow.name
        return Scored(result: result, score: 0)
    }

    private func icon(_ icon: ScriptFilterOutput.Icon?, in workflow: Workflow) -> LaunchResult.Icon {
        if let icon {
            let path = icon.path.hasPrefix("/") ? icon.path
                : (icon.path as NSString).expandingTildeInPath.hasPrefix("/") ? (icon.path as NSString).expandingTildeInPath
                : workflow.folder.appending(path: icon.path).path
            switch icon.type {
            case "fileicon": return .file(path)
            case "filetype": return .symbol("doc")
            default: return .image(path)
            }
        }
        return workflow.icon.map { .image($0.path) } ?? .symbol(Self.symbol)
    }
}
