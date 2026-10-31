import Foundation
import Testing
@testable import ReachKit

/// GitFred's Current Tab task (S-054).
@Test func theFrontBrowserIsAskedForItsTabsURL() {
    #expect(CurrentTab.script(for: "com.apple.Safari") == #"tell application id "com.apple.Safari" to return URL of front document"#)
    #expect(CurrentTab.script(for: "com.google.Chrome")
        == #"tell application id "com.google.Chrome" to return URL of active tab of front window"#)
    #expect(CurrentTab.script(for: "com.apple.mail") == nil)
    #expect(CurrentTab.browser(front: "com.brave.Browser", running: ["com.apple.Safari"]) == "com.brave.Browser")
    #expect(CurrentTab.browser(front: "com.sanderrobijns.reach", running: ["com.google.Chrome", "com.apple.Safari"]) == "com.apple.Safari")
    #expect(CurrentTab.browser(front: nil, running: ["com.apple.mail"]) == nil)
}

@Test func theCurrentTabTaskGoesOnWithTheURL() {
    let plist: [String: Any] = [
        "name": "GitFred",
        "objects": [
            ["uid": "HK", "type": WorkflowHotkey.type, "config": ["argument": 0]],
            ["uid": "TAB", "type": Workflow.automationTask, "config": [
                "taskuid": "com.alfredapp.automation.extras/web-browsers/frontmost-browser/frontmost.tabs.current",
                "tasksettings": ["allow_empty": true],
            ]],
            ["uid": "COPY", "type": Workflow.copyToClipboard, "config": [:]],
        ],
        "connections": ["HK": [["destinationuid": "TAB", "modifiers": 0]], "TAB": [["destinationuid": "COPY", "modifiers": 0]]],
    ]
    let workflow = Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/gitfred.workflow"))
    #expect(workflow.steps(after: "HK", argument: "") == [.currentTab(then: "TAB", allowEmpty: true, variables: [:], environment: [:])])
    #expect(workflow.steps(after: "TAB", argument: "https://github.com/a/b") == [.copy("https://github.com/a/b")])
}
