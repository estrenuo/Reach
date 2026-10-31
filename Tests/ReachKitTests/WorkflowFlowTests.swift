import Foundation
import Testing
@testable import ReachKit

/// The shape of Alfred's Purge Disk Images (S-047): two script filters with a
/// configured keyword, Conditionals, Arg and Vars, an Automation Task and
/// External Triggers that show a list again.
private func purgeWorkflow() -> Workflow {
    let plist: [String: Any] = [
        "name": "Purge Disk Images",
        "bundleid": "com.alfredapp.vitor.purgediskimages",
        "userconfigurationconfig": [
            ["variable": "mounted_keyword", "label": "Mounted", "type": "textfield", "config": ["default": "dmgeject"]],
            ["variable": "file_keyword", "label": "Files", "type": "textfield", "config": ["default": "dmgtrash"]],
        ],
        "objects": [
            ["uid": "MOUNTED", "type": ScriptFilter.type, "config": [
                "keyword": "{var:mounted_keyword}", "argumenttype": 1, "type": 7, "script": "", "scriptargtype": 1,
            ]],
            ["uid": "FILES", "type": ScriptFilter.type, "config": [
                "keyword": "{var:file_keyword}", "argumenttype": 1, "type": 11, "script": "./list", "scriptargtype": 1,
            ]],
            ["uid": "DETACH", "type": Workflow.runScript, "config": [
                "script": "/usr/bin/hdiutil detach \"${mount_point}\"", "type": 11, "scriptargtype": 1,
            ]],
            ["uid": "SETMOUNTED", "type": Workflow.argument, "config": ["argument": "", "variables": ["trash_type": "mounted"]]],
            ["uid": "SETFILE", "type": Workflow.argument, "config": [
                "argument": "", "variables": ["trash_type": "file", "origin_path": "{query}"],
            ]],
            ["uid": "TASK", "type": "alfred.workflow.automation.task", "config": ["taskuid": "path.trash"]],
            ["uid": "HIDEIF", "type": Workflow.conditional, "config": ["conditions": [
                ["uid": "LAST", "inputstring": "{var:last_item}", "matchmode": 5, "matchstring": ""],
            ]]],
            ["uid": "HIDE", "type": Workflow.hideAlfred, "config": [:]],
            ["uid": "WHICH", "type": Workflow.conditional, "config": ["conditions": [
                ["uid": "ISMOUNTED", "inputstring": "{var:trash_type}", "matchmode": 0, "matchstring": "mounted"],
                ["uid": "ISFILE", "inputstring": "{var:trash_type}", "matchmode": 0, "matchstring": "file"],
            ]]],
            ["uid": "CALLMOUNTED", "type": Workflow.callExternalTrigger, "config": [
                "externaltriggerid": "mounted_list", "workflowbundleid": "self",
            ]],
            ["uid": "MOUNTEDLIST", "type": Workflow.externalTrigger, "config": ["triggerid": "mounted_list"]],
            ["uid": "OTHER", "type": Workflow.callExternalTrigger, "config": [
                "externaltriggerid": "x", "workflowbundleid": "com.example.other",
            ]],
        ],
        "connections": [
            "MOUNTED": [["destinationuid": "DETACH", "modifiers": 0], ["destinationuid": "HIDEIF", "modifiers": 0]],
            "FILES": [["destinationuid": "HIDEIF", "modifiers": 0], ["destinationuid": "SETFILE", "modifiers": 0],
                      ["destinationuid": "WHICH", "modifiers": WorkflowConnection.command],
                      ["destinationuid": "OTHER", "modifiers": WorkflowConnection.option]],
            "DETACH": [["destinationuid": "SETMOUNTED", "modifiers": 0]],
            "SETMOUNTED": [["destinationuid": "TASK", "modifiers": 0]],
            "SETFILE": [["destinationuid": "TASK", "modifiers": 0]],
            "HIDEIF": [["destinationuid": "HIDE", "modifiers": 0, "sourceoutputuid": "LAST"]],
            "WHICH": [["destinationuid": "CALLMOUNTED", "modifiers": 0, "sourceoutputuid": "ISMOUNTED"]],
            "MOUNTEDLIST": [["destinationuid": "MOUNTED", "modifiers": 0]],
        ],
    ]
    return Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/purge.workflow"))
}

@Test func aConditionalLineKnowsWhichConditionItLeaves() {
    let workflow = purgeWorkflow()
    #expect(workflow.connections["HIDEIF"] == [WorkflowConnection(to: "HIDE", sourceOutput: "LAST")])
    #expect(workflow.connections["SETFILE"]?.first?.sourceOutput == nil)
}

@Test func conditionsCompareLikeAlfred() {
    #expect(WorkflowCondition.matches("Mounted", "mounted", mode: 0, caseSensitive: false))
    #expect(!WorkflowCondition.matches("Mounted", "mounted", mode: 0, caseSensitive: true))
    #expect(WorkflowCondition.matches("file", "mounted", mode: 1, caseSensitive: false))
    #expect(WorkflowCondition.matches("10", "9", mode: 2, caseSensitive: false))
    #expect(WorkflowCondition.matches("2", "9", mode: 3, caseSensitive: false))
    #expect(!WorkflowCondition.matches("ten", "9", mode: 2, caseSensitive: false))
    #expect(WorkflowCondition.matches("https://github.com/a/b", ".*github.com/.+?/.+", mode: 4, caseSensitive: false))
    #expect(!WorkflowCondition.matches("x", "(", mode: 4, caseSensitive: false))
    for yes in ["true", "1", "YES"] { #expect(WorkflowCondition.matches(yes, "", mode: 5, caseSensitive: false)) }
    for no in ["false", "0", ""] { #expect(WorkflowCondition.matches(no, "", mode: 6, caseSensitive: false)) }
    #expect(!WorkflowCondition.matches("a", "a", mode: 9, caseSensitive: false))
}

@Test func returnOnAFileRunsWhatIsConnectedAndSaysWhatReachSkips() {
    let workflow = purgeWorkflow()
    for last in ["true", "false"] {
        #expect(workflow.steps(after: "FILES", argument: "/tmp/a.dmg", variables: ["last_item": last])
                == [.unsupported("automation.task")])
    }
}

@Test func argAndVarsPassItsVariablesOnAfterAScript() {
    let workflow = purgeWorkflow()
    let steps = workflow.steps(after: "MOUNTED", argument: "See variables", variables: ["mount_point": "/Volumes/X"],
                               environment: ["mount_point": "/Volumes/X"])
    guard case .run(let command, let then, let variables) = steps.first else {
        Issue.record("↩ detaches the image first")
        return
    }
    #expect(command.executable == "/bin/zsh" && command.arguments.first == "--no-rcs")
    #expect(command.environment["mount_point"] == "/Volumes/X" && then == "DETACH" && variables["mount_point"] == "/Volumes/X")
    let after = workflow.steps(after: "DETACH", argument: "", variables: variables, environment: command.environment)
    #expect(after == [.unsupported("automation.task")])
}

@Test func anExternalTriggerShowsItsScriptFilterAgain() {
    let workflow = purgeWorkflow()
    let steps = workflow.steps(after: "FILES", argument: "/tmp/a.dmg", modifiers: WorkflowConnection.command,
                               variables: ["trash_type": "mounted"])
    #expect(steps == [.show("dmgeject ")])
    #expect(workflow.steps(after: "FILES", argument: "", modifiers: WorkflowConnection.command,
                           variables: ["trash_type": "other"]).isEmpty)
    #expect(workflow.steps(after: "FILES", argument: "", modifiers: WorkflowConnection.option)
            == [.unsupported("an External Trigger in another workflow")])
}
