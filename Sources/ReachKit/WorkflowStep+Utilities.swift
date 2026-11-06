import Foundation

extension Workflow {
    /// The steps for one object of this kind (what changes the run on its way: Argument and
    /// Variables, Conditional, Split, Replace, Join, JSON Config, Junction, Delay, Dialog,
    /// Debug, Hide Alfred), or nil when the object is of another kind.
    func utilitySteps(_ object: WorkflowObject, _ flow: WorkflowFlow) -> [WorkflowStep]? {
        let argument = flow.argument
        switch object.type {
        case Self.dialog:
            let buttons = ["button1", "button2", "button3"].map { flow.fill(object.string($0)) }.filter { !$0.isEmpty }
            let step = WorkflowStep.dialog(title: flow.fill(object.string("title")), text: flow.fill(object.string("description")),
                                           buttons: buttons.isEmpty ? ["OK"] : buttons)
            // Sander's dialogs end the workflow; lines out of one are named, not followed.
            return (connections[object.uid] ?? []).isEmpty ? [step] : [step, .unsupported("utility.dialog with lines after it")]
        case Self.delay:
            // `seconds` is text in Alfred's plist, like "0.3".
            let seconds = max(0, object.config["seconds"]?.double ?? 0)
            return [.wait(seconds: seconds, then: object.uid, argument: argument, variables: flow.variables,
                          environment: flow.environment)]
        case Self.junction:
            return next(after: object.uid, flow)
        case Self.argument:
            let text = object.string("argument")
            let set = (object.config["variables"]?.dict ?? [:]).compactMapValues(\.string).mapValues(flow.fill)
            return next(after: object.uid, flow.with(argument: text.isEmpty ? argument : flow.fill(text)).setting(set))
        case Self.conditional:
            let output = WorkflowCondition.output(of: object, query: argument, variables: flow.variables)
            return next(after: object.uid, output: output, flow)
        case Self.split:
            let parts = WorkflowSplit.parts(of: argument, object)
            // As variables the argument goes on as it is; as arguments
            // Reach runs the objects after it once for each part.
            guard object.int("outputas") == 1 else {
                return next(after: object.uid, flow.setting(WorkflowSplit.variables(parts, object)))
            }
            // A Join Arguments right after it gets the parts back as one argument (S-052).
            let lines = (connections[object.uid] ?? []).filter { $0.modifiers == 0 && $0.sourceOutput == nil }
            var after = flow
            after.depth += 1
            return lines.flatMap { line -> [WorkflowStep] in
                if let join = self.object(line.to), join.type == Self.joinArgs {
                    return next(after: join.uid, after.with(argument: parts.joined(separator: join.string("delimiter"))))
                }
                return parts.flatMap { follow([line], after.with(argument: $0)) }
            }
        case Self.replace:
            switch WorkflowReplace.apply(to: argument, object) {
            case .success(let text):
                return next(after: object.uid, flow.with(argument: text))
            case .failure(let problem):
                return [.unsupported(problem.kind)]
            }
        case Self.joinArgs:
            // One argument joins to itself.
            return next(after: object.uid, flow)
        case Self.json:
            guard let output = WorkflowJSON.read(object, query: argument, variables: flow.variables) else {
                return [.unsupported("utility.json with JSON that does not parse")]
            }
            var after = flow.with(argument: output.argument ?? argument).setting(output.variables)
            after.config = output.config
            return next(after: object.uid, after)
        case Self.hideAlfred:
            // Reach hides the launcher after Return anyway.
            return []
        case Self.debug:
            let template = object.string("argument")
            let line = flow.fill(template.isEmpty ? "{query}" : template)
                .replacingOccurrences(of: "{variables}", with: Self.describe(flow.variables))
            // Without "process outputs" the objects after it do not run.
            let after = object.config["processoutputs"]?.bool ?? true ? next(after: object.uid, flow) : []
            return [.debug(line, clear: object.bool("cleardebuggertext"))] + after
        default:
            return nil
        }
    }
}
