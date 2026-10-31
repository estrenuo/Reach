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

@Test func aDialogShowsItsFilledTitleTextAndButtons() {
    let dialog = workflow([["uid": "ASK", "type": Workflow.dialog, "config": [
        "button1": "Ok", "button2": "", "button3": "", "description": "{var:split2}", "title": "Bundle Identifier for\n\"{var:split1}\"",
    ]]], ["KW": line("ASK")])
    #expect(dialog.steps(after: "KW", argument: "x", variables: ["split1": "Safari", "split2": "com.apple.Safari"])
        == [.dialog(title: "Bundle Identifier for\n\"Safari\"", text: "com.apple.Safari", buttons: ["Ok"])])
    let followed = workflow([["uid": "ASK", "type": Workflow.dialog, "config": ["title": "T"]]], ["KW": line("ASK"), "ASK": line("COPY")])
    #expect(followed.steps(after: "KW", argument: "x") == [.dialog(title: "T", text: "", buttons: ["OK"]),
                                                          .unsupported("utility.dialog with lines after it")])
}

@Test func aTerminalCommandIsFilledAndEscapedAsConfigured() {
    let brew = workflow([["uid": "BREW", "type": Workflow.terminalCommand, "config": ["escaping": 0, "script": "brew install {query}"]]],
                        ["KW": line("BREW")])
    #expect(brew.steps(after: "KW", argument: "wget") == [.terminalCommand("brew install wget")])
    let escaped = workflow([["uid": "CMD", "type": Workflow.terminalCommand, "config": ["escaping": 1, "script": "echo {query}"]]],
                           ["KW": line("CMD")])
    #expect(escaped.steps(after: "KW", argument: "a b") == [.terminalCommand(#"echo a\ b"#)])
    #expect(brew.steps(after: "KW", argument: "{var:x}", variables: ["x": "; rm"]) == [.terminalCommand("brew install {var:x}")])
}
