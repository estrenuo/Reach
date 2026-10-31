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
/// wait" row. A new query stops the script that is running. A Keyword
/// input (S-047) shows one row; Return sends the typed text on.
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
    /// Finds files for a File Filter (S-051): a Spotlight query, scopes and a
    /// limit. The self-test swaps in a fake, since Spotlight skips /tmp.
    var findFiles: (_ predicate: String, _ scopes: [String], _ limit: Int,
                    _ done: @escaping @MainActor ([LaunchResult]) -> Void) -> Void
    private let files = FileSearch()
    /// File Filters whose unmapped options the debugger already named.
    private var named: Set<String> = []
    /// The Grid View on screen (S-053) and its script's output once it answered.
    private var grid: (run: WorkflowGridRun, workflow: Workflow, output: ScriptFilterOutput?)?

    private var task: Task<Void, Never>?
    /// Output of filters that let Reach filter: the script runs once while the launcher is open.
    private var cached: [String: ScriptFilterOutput] = [:]

    init(library: WorkflowLibrary = .shared) {
        self.library = library
        findFiles = { [files] predicate, scopes, limit, done in
            files.search(predicate, reveals: false, scopes: scopes, limit: limit, done: done)
        }
        onRun = { [library] workflow, _, text, result in
            library.record(workflow, object: "Script Filter", input: text, result: result)
        }
        onAction = { [library] workflow, _, result in
            library.record(workflow, object: "Run Script", input: nil, result: result)
        }
    }

    static let symbol = "flowchart"

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        switch query {
        case .path, .shell: return []
        default: break
        }
        if let grid { return gridRows(grid, later: later) }
        var rows: [Scored] = []
        var runs: [(workflow: Workflow, filter: ScriptFilter, text: String)] = []
        var search: (workflow: Workflow, filter: FileFilter, text: String)?
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
            for input in workflow.keywordInputs {
                switch input.match(typed) {
                case .keyword:
                    rows.append(Scored(result: keywordRow(input, in: workflow, completes: true),
                                       score: Matcher.score(query: typed, title: input.keyword) ?? 500))
                case .needsText:
                    let done = typed.lowercased() == input.completion.lowercased()
                    rows.append(Scored(result: keywordRow(input, in: workflow, completes: !done), score: 1000))
                case .run(let text):
                    rows.append(Scored(result: inputRow(input, in: workflow, text: text), score: 1000))
                case nil:
                    continue
                }
            }
            for filter in workflow.fileFilters {
                switch filter.match(typed) {
                case .keyword:
                    rows.append(Scored(result: keywordRow(filter, in: workflow, completes: true),
                                       score: Matcher.score(query: typed, title: filter.keyword) ?? 500))
                case .needsText:
                    let done = typed.lowercased() == filter.completion.lowercased()
                    rows.append(Scored(result: keywordRow(filter, in: workflow, completes: !done), score: 1000))
                case .run(let text):
                    if search == nil { search = (workflow, filter, text) }
                case nil:
                    continue
                }
            }
        }
        // One File Filter searches at a time, while no script filter runs.
        if runs.isEmpty, let search {
            return files(for: search.filter, in: search.workflow, text: search.text, rows: rows, later: later)
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
        files.cancel()
    }

    /// The enabled workflows' Fallback Searches for `text` (S-052), after the
    /// web searches; ↩ sends the text on.
    func fallbacks(for text: String) -> [LaunchResult] {
        guard !text.isEmpty else { return [] }
        return library.workflows.filter { !$0.disabled }.flatMap { workflow in
            workflow.fallbacks.map { fallback in
                var result = LaunchResult(id: "fallback:workflow:\(workflow.id):\(fallback.uid)",
                                          title: fallback.title(for: text, workflow: workflow.name), subtitle: workflow.name,
                                          icon: icon(nil, in: workflow))
                result.kindLabel = workflow.name
                result.workflow = WorkflowRun(workflow: workflow.id, filter: fallback.uid, argument: text)
                return result
            }
        }
    }

    /// A File Filter's rows (S-051): "please wait" until Spotlight answers,
    /// then the files, each sending its path on.
    private func files(for filter: FileFilter, in workflow: Workflow, text: String, rows: [Scored],
                       later: @escaping @MainActor ([Scored]) -> Void) -> [Scored] {
        let key = workflow.id + "/" + filter.uid
        if !filter.unmapped.isEmpty, named.insert(key).inserted {
            library.log.failed(workflow: workflow.name,
                               text: "Reach does not follow these File Filter options yet: \(filter.unmapped.joined(separator: ", ")).")
        }
        var waiting = keywordRow(filter, in: workflow, completes: false)
        waiting.id += ":waiting"
        waiting.subtitle = "Searching…"
        findFiles(filter.predicate(for: text), filter.scopes, filter.limit) { [weak self] found in
            guard let self else { return }
            let files = found.enumerated().map { index, file in
                var result = file
                result.id = "workflow:\(workflow.id):\(filter.uid):\(file.id)"
                result.isPinned = true
                result.workflow = WorkflowRun(workflow: workflow.id, filter: filter.uid, argument: file.url?.path ?? file.id)
                return Scored(result: result, score: 1000 - index)
            }
            var none = self.keywordRow(filter, in: workflow, completes: false)
            none.id += ":none"
            none.subtitle = "No files match “\(text)”"
            let answer = rows + (files.isEmpty ? [Scored(result: none, score: 0)] : files)
            // After this call returns its "please wait" row, even when the answer comes at once.
            Task { @MainActor in later(answer) }
        }
        return rows + [Scored(result: waiting, score: 1000)]
    }

    /// The launcher opened again: filters that Reach filters run their script
    /// again, and a Grid View is gone.
    func forget() {
        cached = [:]
        grid = nil
    }

    /// Shows a Grid View's items in the launcher until it opens again (S-053).
    func showGrid(_ run: WorkflowGridRun, in workflow: Workflow) {
        grid = (run, workflow, nil)
    }

    /// The Grid View's items as rows, filtered by what is typed when it is
    /// filterable; a "please wait" row while its script runs.
    private func gridRows(_ grid: (run: WorkflowGridRun, workflow: Workflow, output: ScriptFilterOutput?),
                          later: @escaping @MainActor ([Scored]) -> Void) -> [Scored] {
        let (run, workflow) = (grid.run, grid.workflow)
        guard let output = grid.output else {
            task = Task { [weak self] in
                guard let self else { return }
                let result = await self.run(run.command)
                guard !Task.isCancelled, self.grid?.run == run else { return }
                self.library.record(workflow, object: "Grid View", input: run.command.arguments.first ?? "", result: result)
                // Output that does not parse shows as no items; the debugger has the script's errors.
                guard let output = (try? ScriptFilterOutput.parse(result.output))
                    ?? (try? ScriptFilterOutput.parse(Data(#"{"items": []}"#.utf8))) else { return }
                self.grid = (run, workflow, output)
                later(self.gridRows((run, workflow, output), later: later))
            }
            var waiting = LaunchResult(id: "workflow:\(workflow.id):\(run.uid):waiting", title: workflow.name,
                                       subtitle: run.loading.isEmpty ? ScriptFilter.standardWaiting : run.loading,
                                       icon: icon(nil, in: workflow))
            waiting.kindLabel = workflow.name
            return [Scored(result: waiting, score: 0)]
        }
        let items = run.filterable ? output.filtered(by: typed) : output.items
        guard !items.isEmpty else {
            var none = LaunchResult(id: "workflow:\(workflow.id):\(run.uid):none", title: typed.isEmpty ? "No items" : "No items match “\(typed)”",
                                    subtitle: workflow.name, icon: .symbol("square.grid.3x3"))
            none.kindLabel = workflow.name
            return [Scored(result: none, score: 0)]
        }
        return items.enumerated().map { index, item in
            var result = LaunchResult(id: "workflow:\(workflow.id):\(run.uid):\(index):\(item.uid ?? "")",
                                      title: item.title, subtitle: item.subtitle, icon: icon(item.icon, in: workflow))
            result.kindLabel = workflow.name
            result.isPinned = true
            result.workflow = WorkflowRun(workflow: workflow.id, filter: run.uid, argument: item.argument, valid: item.valid,
                                          variables: run.variables.merging(output.variables) { _, new in new }
                                              .merging(item.variables) { _, new in new }, mods: item.mods)
            return Scored(result: result, score: 1000 - index)
        }
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
    private func keywordRow(_ trigger: some KeywordTrigger, in workflow: Workflow, completes: Bool) -> LaunchResult {
        var result = LaunchResult(id: "workflow:\(workflow.id):\(trigger.uid)", title: trigger.placeholder,
                                  subtitle: trigger.subtext.isEmpty ? workflow.name : trigger.subtext, icon: icon(nil, in: workflow))
        result.kindLabel = workflow.name
        if completes { result.completes = trigger.completion }
        return result
    }

    /// A Keyword input with its text typed: Return sends the text on to
    /// the objects connected to it.
    private func inputRow(_ input: KeywordInput, in workflow: Workflow, text: String) -> LaunchResult {
        var result = LaunchResult(id: "workflow:\(workflow.id):\(input.uid):run", title: input.title(for: text),
                                  subtitle: input.subtext.isEmpty ? workflow.name : WorkflowText.fill(input.subtext, query: text),
                                  icon: icon(nil, in: workflow))
        result.kindLabel = workflow.name
        result.isPinned = true
        result.workflow = WorkflowRun(workflow: workflow.id, filter: input.uid, argument: text)
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
