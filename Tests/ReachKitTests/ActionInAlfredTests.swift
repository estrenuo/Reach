import Foundation
import Testing
@testable import ReachKit

/// Rename Action's Action in Alfred (S-054): the actions for the file again.
private func actionWorkflow(_ config: [String: Any]) -> Workflow {
    let plist: [String: Any] = [
        "name": "Rename",
        "objects": [
            ["uid": "KW", "type": KeywordInput.type, "config": ["keyword": "r"]],
            ["uid": "ACT", "type": Workflow.actionInAlfred, "config": config],
        ],
        "connections": ["KW": [["destinationuid": "ACT", "modifiers": 0]]],
    ]
    return Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/rename.workflow"))
}

@Test func actionInAlfredOpensTheActionsForThePath() {
    let workflow = actionWorkflow(["jumpto": "_popUpItemAction:", "path": "", "type": 1])
    #expect(workflow.steps(after: "KW", argument: "/Users/ada/new name.txt") == [.actions("/Users/ada/new name.txt")])
    #expect(actionWorkflow(["jumpto": "_popUpItemAction:", "path": "{query}/a", "type": 1]).steps(after: "KW", argument: "~")
        == [.actions("~/a")])
}

@Test func anotherKindOfActionInAlfredIsNamed() {
    #expect(actionWorkflow(["type": 0, "jumpto": ""]).steps(after: "KW", argument: "x") == [.unsupported("action.actioninalfred type 0")])
}
