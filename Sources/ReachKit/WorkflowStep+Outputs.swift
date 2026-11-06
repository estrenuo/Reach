import Foundation

extension Workflow {
    /// The steps for one object of this kind (what the person sees or gets: Copy, Large Type,
    /// notifications, sounds, key presses, Text View, Grid View, External Triggers and the
    /// script filter or keyword they lead to), or nil when the object is of another kind.
    func outputSteps(_ object: WorkflowObject, _ flow: WorkflowFlow) -> [WorkflowStep]? {
        let argument = flow.argument
        switch object.type {
        case Self.textView:
            // Only the plain text view, as Homebrew uses it; a script as input
            // (inputtype 1), output to the next objects, or a footer is not mapped.
            // `fontsizing` and `stackview` only change how Alfred draws it.
            let plain = ["inputtype", "outputmode", "behaviour", "fontmode"].filter { object.int($0) != 0 }
                .map { "\($0) \(object.int($0))" }
                + ["footertext", "loadingtext"].filter { !object.string($0).isEmpty }
            guard plain.isEmpty else { return [.unsupported("userinterface.text with \(plain.joined(separator: ", "))")] }
            let step = WorkflowStep.textView(argument)
            return (connections[object.uid] ?? []).isEmpty ? [step] : [step, .unsupported("userinterface.text with lines after it")]
        case Self.grid:
            // Input type 1: a script in the workflow folder gets the argument and prints Script Filter JSON.
            let file = object.string("inputfile")
            guard object.int("inputtype") == 1, !file.isEmpty,
                  let command = ScriptSource(language: .file, file: file).command(query: argument, folder: folder,
                                                                                environment: flow.environment)
            else { return [.unsupported("userinterface.grid with input type \(object.int("inputtype"))")] }
            return [.grid(WorkflowGridRun(uid: object.uid, command: command, variables: flow.variables,
                                          filterable: object.bool("filterable"), loading: object.string("loadingtext")))]
        case Self.dispatchKeys:
            switch WorkflowKeys.read(object) {
            case .success(let keys):
                return [.keys(keys)] + next(after: object.uid, flow)
            case .failure(let problem):
                return [.unsupported(problem.kind)]
            }
        case Self.copyToClipboard:
            let text = object.string("clipboardtext")
            return [.copy(text.isEmpty ? argument : flow.fill(text))]
        case Self.largeType:
            let text = object.string("largetypetext")
            return [.largeType(text.isEmpty ? argument : flow.fill(text))]
        case Self.callExternalTrigger:
            let bundle = object.string("workflowbundleid")
            guard ["", "self", bundleID].contains(bundle) else { return [.unsupported("an External Trigger in another workflow")] }
            let id = object.string("externaltriggerid")
            guard let trigger = objects.first(where: { $0.type == Self.externalTrigger && $0.string("triggerid") == id })
            else { return [] }
            let passes = object.bool("passvariables")
            // Without passvariables the trigger starts from the workflow's own variables.
            let own = flow.environment.filter { key, _ in flow.variables[key] == nil || self.variables[key] != nil }
            var after = flow.with(argument: object.bool("passinputasargument") ? argument : "")
            if !passes {
                after.variables = self.variables
                after.environment = own
            }
            return next(after: trigger.uid, after)
        case Self.notification:
            // Like Alfred, the argument goes on to the objects after it.
            let after = next(after: object.uid, flow)
            if object.bool("onlyshowifquerypopulated") && argument.isEmpty { return after }
            var shown = argument
            if object.bool("lastpathcomponent") { shown = (shown as NSString).lastPathComponent }
            if object.bool("removeextension") { shown = (shown as NSString).deletingPathExtension }
            let title = WorkflowText.fill(object.string("title"), query: shown, variables: flow.variables)
            return [.notify(title: title.isEmpty ? name : title,
                            text: WorkflowText.fill(object.string("text"), query: shown, variables: flow.variables))] + after
        case Self.playSound:
            let name = object.string("soundname")
            let after = next(after: object.uid, flow)
            guard !name.isEmpty else { return after }
            // A sound that is not a system sound is a file in the workflow's folder.
            return [.sound(object.bool("systemsound") ? name : folder.appending(path: name).path)] + after
        case ScriptFilter.type, KeywordInput.type:
            guard let keyword = scriptFilters.first(where: { $0.uid == object.uid })?.keyword
                ?? keywordInputs.first(where: { $0.uid == object.uid })?.keyword else { return [] }
            return [.show(keyword + " " + argument)]
        default:
            return nil
        }
    }
}
