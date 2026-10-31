import Foundation
import Testing
@testable import ReachKit

/// Split Arguments as Alfred writes it (S-051).
private func splitWorkflow(outputAs: Int, delimiter: String = "\t", trim: Bool = true, discard: Bool = false) -> Workflow {
    let plist: [String: Any] = [
        "name": "Split",
        "objects": [
            ["uid": "KW", "type": KeywordInput.type, "config": ["keyword": "sp"]],
            ["uid": "SPLIT", "type": Workflow.split, "config": [
                "delimiter": delimiter, "outputas": outputAs, "trimarguments": trim, "discardemptyarguments": discard,
                "variableprefix": "split",
            ]],
            ["uid": "COPY", "type": Workflow.copyToClipboard, "config": ["clipboardtext": "{query}|{var:split1}|{var:split2}"]],
        ],
        "connections": [
            "KW": [["destinationuid": "SPLIT", "modifiers": 0]],
            "SPLIT": [["destinationuid": "COPY", "modifiers": 0]],
        ],
    ]
    return Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/split.workflow"))
}

@Test func splitAsArgumentsRunsTheNextObjectsOncePerPart() {
    #expect(splitWorkflow(outputAs: 1).steps(after: "KW", argument: "/a\t/b") == [.copy("/a|{var:split1}|{var:split2}"),
                                                                              .copy("/b|{var:split1}|{var:split2}")])
}

@Test func splitAsVariablesKeepsTheArgument() {
    #expect(splitWorkflow(outputAs: 0, delimiter: ",").steps(after: "KW", argument: "set, com.apple.Safari")
        == [.copy("set, com.apple.Safari|set|com.apple.Safari")])
}

@Test func splitTrimsAndDropsEmptyPartsAsConfigured() {
    let object = WorkflowObject(uid: "S", type: Workflow.split, config: [
        "delimiter": .string(","), "trimarguments": .bool(true), "discardemptyarguments": .bool(true),
    ])
    #expect(WorkflowSplit.parts(of: " a ,, b", object) == ["a", "b"])
    let raw = WorkflowObject(uid: "S", type: Workflow.split, config: ["delimiter": .string(",")])
    #expect(WorkflowSplit.parts(of: " a ,, b", raw) == [" a ", "", " b"])
    #expect(WorkflowSplit.variables(["x", "y"], raw) == ["split1": "x", "split2": "y"])
}
