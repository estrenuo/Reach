import Foundation
import Testing
@testable import ReachKit

/// The objects of S-055, as Sander's workflows write them.
private func workflow(_ objects: [[String: Any]], _ connections: [String: Any]) -> Workflow {
    let plist: [String: Any] = [
        "name": "S055",
        "objects": [["uid": "KW", "type": KeywordInput.type, "config": ["keyword": "s"]]] + objects
            + [["uid": "COPY", "type": Workflow.copyToClipboard, "config": [:]]],
        "connections": connections,
    ]
    return Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/s055.workflow"))
}

private func line(_ to: String, _ modifiers: Int = 0) -> [[String: Any]] { [["destinationuid": to, "modifiers": modifiers]] }

@Test func aDelayWaitsThenGoesOnWithTheArgument() {
    let delayed = workflow([["uid": "WAIT", "type": Workflow.delay, "config": ["seconds": "0.3"]]],
                           ["KW": line("WAIT"), "WAIT": line("COPY")])
    #expect(delayed.steps(after: "KW", argument: "x") == [.wait(seconds: 0.3, then: "WAIT", argument: "x", variables: [:], environment: [:])])
    #expect(delayed.steps(after: "WAIT", argument: "x") == [.copy("x")])
}
