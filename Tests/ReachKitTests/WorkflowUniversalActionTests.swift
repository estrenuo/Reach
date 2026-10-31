import Foundation
import Testing
@testable import ReachKit

/// Universal Actions as Sander's workflows write them (S-052).
private func universalWorkflow() -> Workflow {
    let plist: [String: Any] = [
        "name": "Universal",
        "objects": [
            ["uid": "SHORTCUT", "type": WorkflowUniversalAction.type, "config": [
                "name": "Run Shortcut", "acceptsfiles": false, "acceptstext": true, "acceptsurls": true, "acceptsmulti": 0,
            ]],
            ["uid": "CHAT", "type": WorkflowUniversalAction.type, "config": [
                "name": "Ask ChatGPT", "acceptsfiles": false, "acceptstext": true, "acceptsurls": false, "acceptsmulti": 0,
            ]],
            ["uid": "CODE", "type": WorkflowUniversalAction.type, "config": [
                "name": "Open with VS Code", "acceptsfiles": true, "acceptstext": true, "acceptsurls": false, "acceptsmulti": 1,
            ]],
            ["uid": "COPY", "type": Workflow.copyToClipboard, "config": [:]],
        ],
        "connections": ["CODE": [["destinationuid": "COPY", "modifiers": 0]]],
    ]
    return Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/universal.workflow"))
}

@Test func universalActionsAreReadWithWhatTheyAccept() {
    let actions = universalWorkflow().universalActions
    #expect(actions.map(\.name) == ["Run Shortcut", "Ask ChatGPT", "Open with VS Code"])
    #expect(actions[0] == WorkflowUniversalAction(uid: "SHORTCUT", name: "Run Shortcut", acceptsText: true, acceptsURLs: true))
    #expect(actions[2].acceptsFiles && actions[2].acceptsMany)
}

@Test func aUniversalActionShowsForTheKindsItAccepts() {
    let actions = universalWorkflow().universalActions
    let url = "https://example.com/docs"
    #expect(actions[0].accepts(text: url) && actions[0].accepts(text: "hello"))
    #expect(!actions[1].accepts(text: url) && actions[1].accepts(text: "hello"))
    #expect(!actions[0].accepts([URL(fileURLWithPath: "/tmp/a")]))
    #expect(actions[2].accepts([URL(fileURLWithPath: "/tmp/a"), URL(fileURLWithPath: "/tmp/b")]))
    #expect(!actions[1].accepts(text: ""))
}

@Test func onlyOneWebAddressCountsAsAURL() {
    #expect(WorkflowUniversalAction.isURL(" https://example.com/a?b=c "))
    #expect(!WorkflowUniversalAction.isURL("see https://example.com"))
    #expect(!WorkflowUniversalAction.isURL("mailto:ada@example.com"))
    #expect(!WorkflowUniversalAction.isURL("example"))
}

@Test func aUniversalActionSendsItsInputOn() {
    #expect(universalWorkflow().steps(after: "CODE", argument: "/tmp/a\t/tmp/b") == [.copy("/tmp/a\t/tmp/b")])
}
