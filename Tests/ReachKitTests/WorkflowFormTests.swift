import Foundation
import Testing
@testable import ReachKit

@Test func everyPaletteKindHasAFormWithOneFieldPerConfigKey() {
    for kind in WorkflowPalette.kinds {
        let keys = WorkflowForm.fields(kind.type).map(\.key)
        #expect(keys.count == Set(keys).count, "\(kind.name) has a key twice")
        #expect(Set(keys) == Set(kind.config.keys), "\(kind.name)")
        #expect(WorkflowForm.fields(kind.type).allSatisfy { !$0.label.isEmpty && $0.label.first!.isUppercase }, "\(kind.name)")
    }
}

@Test func theFieldsFitTheirValues() {
    let filter = Dictionary(uniqueKeysWithValues: WorkflowForm.fields(ScriptFilter.type).map { ($0.key, $0) })
    #expect(filter["keyword"]?.kind == .text && filter["withspace"]?.kind == .toggle)
    #expect(filter["script"]?.kind == .lines(code: true))
    if case .choice(let languages) = filter["type"]?.kind { #expect(languages.contains { $0.value == 11 }) } else { Issue.record("no language choice") }
    #expect(WorkflowForm.fields(ScriptFilter.type).first?.key == "keyword")
    #expect(WorkflowForm.fields(Workflow.openURL).first?.key == "url")
    #expect(WorkflowForm.fields(Workflow.argument).first { $0.key == "variables" }?.kind == .structured)
    #expect(WorkflowForm.fields("alfred.workflow.output.somethingnew").isEmpty)
}

@Test func theSheetOpensWithTheObjectsOwnValues() {
    let object = WorkflowObject(uid: "U", type: Workflow.openURL, config: ["url": .string("https://a.example"), "extra": .int(1)])
    let values = WorkflowForm.values(object)
    #expect(values["url"] == .string("https://a.example") && values["browser"] == .string(""))
    #expect(values["extra"] == nil)
}

@Test func savingKeepsKeysTheFormDoesNotKnow() {
    var plist: [String: Any] = ["name": "W", "objects": [
        ["uid": "U", "type": Workflow.openURL, "version": 1, "config": ["url": "https://old.example", "newinalfred6": ["a": 1]]],
        ["uid": "V", "type": Workflow.junction, "config": [:] as [String: Any]],
    ]]
    let before = plist as NSDictionary
    WorkflowEdit.configure("U", values: ["url": .string("https://new.example"), "skipqueryencode": .bool(true)], in: &plist)
    let config = WorkflowEdit.config("U", in: plist)
    #expect(config?["url"] as? String == "https://new.example" && config?["skipqueryencode"] as? Bool == true)
    #expect((config?["newinalfred6"] as? [String: Int]) == ["a": 1])
    let objects = plist["objects"] as! [[String: Any]]
    #expect(objects[0]["version"] as? Int == 1 && (objects[1] as NSDictionary) == ((before["objects"] as! [[String: Any]])[1] as NSDictionary))
    #expect(plist["name"] as? String == "W")
    // Undo puts the whole config back.
    WorkflowEdit.setConfig("U", (before["objects"] as! [[String: Any]])[0]["config"] as! [String: Any], in: &plist)
    #expect((plist as NSDictionary) == before)
}

@Test func listsAndDictionariesAreEditedAsJSON() throws {
    let variables = PlistValue.dict(["name": .string("Ada"), "count": .int(2)])
    let text = WorkflowForm.json(variables)
    #expect(try WorkflowForm.value(json: text, like: variables, label: "Variables") == variables)
    #expect(try WorkflowForm.value(json: "", like: .array([]), label: "Scopes") == .array([]))
    #expect(throws: WorkflowForm.Failure.notJSON(label: "Variables")) { try WorkflowForm.value(json: "[1]", like: variables, label: "Variables") }
    #expect(throws: WorkflowForm.Failure.notJSON(label: "Variables")) { try WorkflowForm.value(json: "{nope", like: variables, label: "Variables") }
}
