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

@Test func postNotificationShowsTheFileNameAndCanWaitForText() {
    let named = outputWorkflow(Workflow.notification, ["title": "", "text": "{query}", "lastpathcomponent": true,
                                                       "removeextension": true])
    #expect(named.steps(after: "KW", argument: "/tmp/a/photo.jpg")
            == [.notify(title: "Outputs", text: "photo"), .copy("/tmp/a/photo.jpg")])
    let waits = outputWorkflow(Workflow.notification, ["title": "Done", "text": "{query}", "onlyshowifquerypopulated": true])
    #expect(waits.steps(after: "KW", argument: "") == [.copy("")])
    #expect(waits.steps(after: "KW", argument: "x") == [.notify(title: "Done", text: "x"), .copy("x")])
}
