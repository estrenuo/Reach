import Foundation
import Testing
@testable import ReachKit

/// A keyword whose text goes through an output object to Copy to Clipboard
/// (S-048), as Alfred passes the argument on.
private func outputWorkflow(_ type: String, _ config: [String: Any]) -> Workflow {
    let plist: [String: Any] = [
        "name": "Outputs",
        "variables": ["who": "Sander"],
        "objects": [
            ["uid": "KW", "type": KeywordInput.type, "config": ["keyword": "out", "argumenttype": 1, "text": "Out"]],
            ["uid": "OUT", "type": type, "config": config],
            ["uid": "COPY", "type": Workflow.copyToClipboard, "config": ["clipboardtext": "{query}"]],
        ],
        "connections": [
            "KW": [["destinationuid": "OUT", "modifiers": 0]],
            "OUT": [["destinationuid": "COPY", "modifiers": 0]],
        ],
    ]
    return Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/outputs.workflow"))
}

@Test func postNotificationFillsItsTextAndPassesTheArgumentOn() {
    let workflow = outputWorkflow(Workflow.notification, ["title": "Hi {var:who}", "text": "Got {query}"])
    #expect(workflow.steps(after: "KW", argument: "a b", variables: ["who": "Sander"])
            == [.notify(title: "Hi Sander", text: "Got a b"), .copy("a b")])
}

@Test func playSoundPlaysASystemSoundOrAFileInTheWorkflowAndPassesTheArgumentOn() {
    #expect(outputWorkflow(Workflow.playSound, ["soundname": "Blow", "systemsound": true]).steps(after: "KW", argument: "x")
            == [.sound("Blow"), .copy("x")])
    #expect(outputWorkflow(Workflow.playSound, ["soundname": "End.aif", "systemsound": false]).steps(after: "KW", argument: "x")
            == [.sound("/tmp/outputs.workflow/End.aif"), .copy("x")])
    #expect(outputWorkflow(Workflow.playSound, ["soundname": ""]).steps(after: "KW", argument: "x") == [.copy("x")])
}

@Test func debugWritesItsLineWithTheVariablesAndPassesTheArgumentOn() {
    let debug = outputWorkflow(Workflow.debug, ["argument": "'{query}', {variables}", "cleardebuggertext": true,
                                                "processoutputs": true])
    #expect(debug.steps(after: "KW", argument: "x", variables: ["b": "2", "a": "1"])
            == [.debug("'x', {a = 1, b = 2}", clear: true), .copy("x")])
    let stops = outputWorkflow(Workflow.debug, ["argument": "", "processoutputs": false])
    #expect(stops.steps(after: "KW", argument: "x") == [.debug("x", clear: false)])
}

@Test func theDebuggerClearsOnlyThisWorkflowsLines() {
    var log = WorkflowLog()
    log.debug(workflow: "A", text: "one")
    log.debug(workflow: "B", text: "two")
    log.debug(workflow: "A", text: "three", clear: true)
    #expect(log.entries.map(\.text) == ["two", "three"])
}

@Test func postNotificationShowsTheFileNameAndCanWaitForText() {
    let named = outputWorkflow(Workflow.notification, ["title": "", "text": "{query}", "lastpathcomponent": true,
                                                       "removeextension": true])
    #expect(named.steps(after: "KW", argument: "/tmp/a/photo.jpg")
            == [.notify(title: "Outputs", text: "photo"), .copy("/tmp/a/photo.jpg")])
    let waits = outputWorkflow(Workflow.notification, ["title": "Done", "text": "{query}", "onlyshowifquerypopulated": true])
    #expect(waits.steps(after: "KW", argument: "") == [.copy("")])
    #expect(waits.steps(after: "KW", argument: "x") == [.notify(title: "Done", text: "x"), .copy("x")])
}
