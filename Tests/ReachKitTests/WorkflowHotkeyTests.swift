import Foundation
import Testing
@testable import ReachKit

/// Hotkey triggers as Alfred writes them (S-049): no key combination in an
/// exported workflow, an argument kind, and related apps.
private func hotkeyWorkflow() -> Workflow {
    let plist: [String: Any] = [
        "name": "Player",
        "objects": [
            ["uid": "NONE", "type": WorkflowHotkey.type, "config": [
                "action": 0, "argument": 0, "relatedAppsMode": 0, "modsmode": 0, "leftcursor": false,
            ]],
            ["uid": "SEL", "type": WorkflowHotkey.type, "config": [
                "action": 0, "argument": 1, "relatedAppsMode": 1, "relatedApps": ["com.apple.finder"],
            ]],
            ["uid": "TEXT", "type": WorkflowHotkey.type, "config": ["action": 1, "argument": 3, "argumenttext": "Browse▹"]],
            ["uid": "KEYED", "type": WorkflowHotkey.type, "config": [
                "argument": 2, "hotkey": 1, "hotmod": (1 << 20) | (1 << 19), "hotstring": "S", "relatedAppsMode": 2,
                "relatedApps": ["com.apple.Safari"],
            ]],
            ["uid": "FIND", "type": WorkflowHotkey.type, "config": ["argument": 4]],
            ["uid": "SF", "type": ScriptFilter.type, "config": ["keyword": "play", "title": "Play a Song", "type": 0]],
        ],
        "connections": [
            "NONE": [["destinationuid": "SF", "modifiers": 0]],
            "TEXT": [["destinationuid": "SF", "modifiers": 0]],
        ],
        "uidata": ["TEXT": ["note": "Browse the library", "xpos": 10, "ypos": 10]],
    ]
    return Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/player.workflow"))
}

@Test func hotkeyTriggersAreReadWithTheirArgumentAndApps() {
    let hotkeys = hotkeyWorkflow().hotkeys
    #expect(hotkeys.map(\.uid) == ["NONE", "SEL", "TEXT", "KEYED", "FIND"])
    #expect(hotkeys[0] == WorkflowHotkey(uid: "NONE"))
    #expect(hotkeys[1].argument == .selection && hotkeys[1].apps == ["com.apple.finder"] && hotkeys[1].appsMode == 1)
    #expect(hotkeys[2].argument == .text("Browse▹") && hotkeys[2].showsLauncher)
    #expect(hotkeys[3].combo == KeyCombo(keyCode: 1, modifiers: KeyCombo.command | KeyCombo.option) && hotkeys[3].keyName == "S")
    #expect(hotkeys[0].combo == nil)
    #expect(hotkeys[4].argument == .other(4))
}

@Test func theArgumentIsWhatAlfredWouldPass() {
    let hotkeys = hotkeyWorkflow().hotkeys
    #expect(hotkeys[0].text(selection: "sel", clipboard: "clip") == ("", nil))
    #expect(hotkeys[1].text(selection: "sel", clipboard: "clip") == ("sel", nil))
    #expect(hotkeys[1].text(selection: nil, clipboard: "clip") == ("", nil))
    #expect(hotkeys[2].text(selection: "sel", clipboard: "clip") == ("Browse▹", nil))
    #expect(hotkeys[3].text(selection: "sel", clipboard: "clip") == ("clip", nil))
    #expect(hotkeys[4].text(selection: "sel", clipboard: "clip") == ("", "the Find pasteboard"))
}

@Test func relatedAppsDecideWhenAHotkeyWorks() {
    let hotkeys = hotkeyWorkflow().hotkeys
    #expect(hotkeys[0].isActive(frontApp: "com.apple.mail"))
    #expect(hotkeys[1].isActive(frontApp: "com.apple.finder") && !hotkeys[1].isActive(frontApp: "com.apple.mail"))
    #expect(!hotkeys[3].isActive(frontApp: "com.apple.Safari") && hotkeys[3].isActive(frontApp: nil))
}

@Test func aHotkeyIsLabelledByItsNoteOrWhatItRuns() {
    let workflow = hotkeyWorkflow()
    #expect(workflow.label(forHotkey: "TEXT") == "Browse the library")
    #expect(workflow.label(forHotkey: "NONE") == "Play a Song")
    #expect(workflow.label(forHotkey: "SEL") == "Hotkey")
}

@Test func aHotkeyThatIsTakenIsSkippedNotStolen() {
    let a = KeyCombo(keyCode: 1, modifiers: KeyCombo.command | KeyCombo.option)
    let b = KeyCombo(keyCode: 2, modifiers: KeyCombo.control)
    let wanted = [
        WorkflowHotkeyPlan.Entry(workflow: "One", uid: "1", combo: a),
        WorkflowHotkeyPlan.Entry(workflow: "Two", uid: "2", combo: a),
        WorkflowHotkeyPlan.Entry(workflow: "Two", uid: "3", combo: KeyCombo.default),
        WorkflowHotkeyPlan.Entry(workflow: "Two", uid: "4", combo: b),
    ]
    let plan = WorkflowHotkeyPlan.plan(wanted, reserved: [("launcher hotkey", KeyCombo.default)])
    #expect(plan.use.map(\.uid) == ["1", "4"])
    #expect(plan.skipped.map(\.entry.uid) == ["2", "3"])
    #expect(plan.skipped.map(\.reason) == ["the workflow “One” has it", "it is Reach's launcher hotkey"])
}

@Test func returnFromAHotkeyShowsTheScriptFilterWithItsText() {
    #expect(hotkeyWorkflow().steps(after: "TEXT", argument: "Browse▹") == [.show("play Browse▹")])
}
