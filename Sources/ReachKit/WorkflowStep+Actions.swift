import Foundation

extension Workflow {
    /// The steps for one object of this kind (opening, revealing, running: Open URL, Open
    /// File, Reveal, Terminal Command, Action in Alfred, Browse in Terminal, Run Script), or
    /// nil when the object is of another kind.
    func actionSteps(_ object: WorkflowObject, _ flow: WorkflowFlow) -> [WorkflowStep]? {
        let argument = flow.argument
        switch object.type {
        case Self.openURL:
            let template = object.string("url")
            return [.open(template.isEmpty ? argument : WorkflowText.fill(template, query: argument, variables: flow.variables,
                                                                         encodeQuery: template != "{query}"))]
        case Self.openFile:
            let file = object.string("sourcefile")
            return [.open(file.isEmpty ? argument : flow.fill(file))]
        case Self.revealFile:
            return [.reveal(argument)]
        case Self.terminalCommand:
            // `{query}` escaped as `escaping` says, like an inline script; one
            // pass, so text in the argument is never filled again.
            let query = ScriptSource.escape(argument, object.int("escaping"))
            return [.terminalCommand(WorkflowText.fill(object.string("script"), query: query, variables: flow.variables))]
        case Self.actionInAlfred:
            // Type 1 jumping to `_popUpItemAction:`: the actions for the path (the argument when empty).
            guard object.int("type") == 1, ["", "_popUpItemAction:"].contains(object.string("jumpto")) else {
                return [.unsupported("action.actioninalfred type \(object.int("type")) \(object.string("jumpto"))"
                    .trimmingCharacters(in: .whitespaces))]
            }
            let path = object.string("path")
            return [.actions(path.isEmpty ? argument : flow.fill(path))]
        case Self.browseInTerminal:
            // An empty path is the argument; the objects after it get the same argument.
            let path = object.string("path")
            return [.terminal(path.isEmpty ? argument : flow.fill(path))] + next(after: object.uid, flow)
        case Self.runScript:
            guard let command = ScriptSource(object).command(query: argument, folder: folder, environment: flow.environment)
            else { return [.unsupported("a script in this language")] }
            return [.run(command, then: object.uid, variables: flow.variables)]
        default:
            return nil
        }
    }
}
