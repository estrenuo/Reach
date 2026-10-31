import Foundation
import Testing
@testable import ReachKit

/// Dispatch Key Combo as Sander's workflows write it (S-053): ⌘V and ⌘A by character.
private func keys(_ config: [String: PlistValue]) -> WorkflowObject {
    WorkflowObject(uid: "K", type: Workflow.dispatchKeys, config: config)
}

@Test func aKeyComboIsReadFromItsCharacterAndModifiers() {
    let paste = keys(["count": .int(1), "keychar": .string("v"), "keycode": .int(-1), "keymod": .int(1_048_576),
                      "overridewithargument": .bool(false)])
    #expect(WorkflowKeys.read(paste) == .success(WorkflowKeys(keyCode: 9, modifiers: 1 << 20)))
    #expect(WorkflowKeys.read(keys(["keychar": .string("A"), "keycode": .int(-1), "keymod": .int(1_048_576)]))
        == .success(WorkflowKeys(keyCode: 0, modifiers: 1 << 20)))
    #expect(WorkflowKeys.read(keys(["keycode": .int(36), "count": .int(3)])) == .success(WorkflowKeys(keyCode: 36, count: 3)))
}

@Test func keysReachDoesNotPressAreNamed() {
    #expect(WorkflowKeys.read(keys(["keychar": .string("v"), "overridewithargument": .bool(true)]))
        == .failure(.init(kind: "output.dispatchkeycombo with the argument as the keys")))
    #expect(WorkflowKeys.read(keys(["keychar": .string("é"), "keycode": .int(-1)]))
        == .failure(.init(kind: "output.dispatchkeycombo for the key “é”")))
}

@Test func aKeyComboIsAStepAndTheWorkflowGoesOn() {
    let plist: [String: Any] = [
        "name": "Keys",
        "objects": [
            ["uid": "KW", "type": KeywordInput.type, "config": ["keyword": "k"]],
            ["uid": "K", "type": Workflow.dispatchKeys, "config": ["keychar": "a", "keycode": -1, "keymod": 1_048_576, "count": 1]],
            ["uid": "COPY", "type": Workflow.copyToClipboard, "config": [:]],
        ],
        "connections": ["KW": [["destinationuid": "K", "modifiers": 0]], "K": [["destinationuid": "COPY", "modifiers": 0]]],
    ]
    let workflow = Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/keys.workflow"))
    #expect(workflow.steps(after: "KW", argument: "x") == [.keys(WorkflowKeys(keyCode: 0, modifiers: 1 << 20)), .copy("x")])
}
