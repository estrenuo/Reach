import Foundation

extension Workflow {
    /// The steps for one object of this kind (Automation Tasks: the Trash, the current tab,
    /// the Finder, Shortcuts), or nil when the object is of another kind.
    func taskSteps(_ object: WorkflowObject, _ flow: WorkflowFlow) -> [WorkflowStep]? {
        let argument = flow.argument
        switch object.type {
        case Self.automationTask where object.string("taskuid").hasSuffix(CurrentTab.taskSuffix):
            let allowEmpty = object.config["tasksettings"]?.dict?["allow_empty"]?.bool ?? false
            return [.currentTab(then: object.uid, allowEmpty: allowEmpty, variables: flow.variables, environment: flow.environment)]
        case WorkflowShortcut.runType:
            switch WorkflowShortcut.run(object, argument: argument, variables: flow.variables, folder: folder,
                                        environment: flow.environment) {
            case .success(let command): return [.run(command, then: object.uid, variables: flow.variables)]
            case .failure(let problem): return [.unsupported(problem.kind)]
            }
        case Self.automationTask where FinderTask.command(for: object.string("taskuid"), folder: folder,
                                                          environment: flow.environment) != nil:
            let command = FinderTask.command(for: object.string("taskuid"), folder: folder, environment: flow.environment)!
            return [.run(command, then: object.uid, variables: flow.variables)]
        case Self.automationTask where object.string("taskuid") == WorkflowShortcut.viewTask:
            let command = WorkflowShortcut.view(object, argument: argument, variables: flow.variables, folder: folder,
                                                environment: flow.environment)
            return [.run(command, then: object.uid, variables: flow.variables)]
        case Self.automationTask where object.string("taskuid") == Self.trashTask:
            let target = object.config["tasksettings"]?.dict?["target_path"]?.string ?? ""
            let path = target.isEmpty ? argument : flow.fill(target)
            // The objects after it run once the file is in the Trash, with its path.
            return [.trash(path)] + next(after: object.uid, flow.with(argument: path))
        default:
            return nil
        }
    }
}
