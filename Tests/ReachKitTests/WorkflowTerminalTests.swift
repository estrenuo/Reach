import Foundation
import Testing
@testable import ReachKit

/// Browse in Terminal as Sander's workflows use it (S-053): the path, or the argument when empty.
@Test func browseInTerminalOpensThePathAndGoesOn() {
    let plist: [String: Any] = [
        "name": "Terminal",
        "objects": [
            ["uid": "KW", "type": KeywordInput.type, "config": ["keyword": "t"]],
            ["uid": "FILLED", "type": Workflow.browseInTerminal, "config": ["path": "{query}/sub"]],
            ["uid": "EMPTY", "type": Workflow.browseInTerminal, "config": ["path": ""]],
            ["uid": "COPY", "type": Workflow.copyToClipboard, "config": [:]],
        ],
        "connections": [
            "KW": [["destinationuid": "FILLED", "modifiers": 0], ["destinationuid": "EMPTY", "modifiers": 0]],
            "FILLED": [["destinationuid": "COPY", "modifiers": 0]],
        ],
    ]
    let workflow = Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/terminal.workflow"))
    #expect(workflow.steps(after: "KW", argument: "~/Vault") == [.terminal("~/Vault/sub"), .copy("~/Vault"), .terminal("~/Vault")])
}
