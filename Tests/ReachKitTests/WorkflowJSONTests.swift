import Foundation
import Testing
@testable import ReachKit

/// JSON Config as Sander's workflows use it (S-052): the argument, and the next object's configuration.
private func jsonWorkflow(_ json: String) -> Workflow {
    let plist: [String: Any] = [
        "name": "JSON",
        "objects": [
            ["uid": "KW", "type": KeywordInput.type, "config": ["keyword": "j"]],
            ["uid": "JSON", "type": Workflow.json, "config": ["json": json]],
            ["uid": "COPY", "type": Workflow.copyToClipboard, "config": ["clipboardtext": "{query}"]],
        ],
        "variables": ["shortcut": "Make GIF"],
        "connections": ["KW": [["destinationuid": "JSON", "modifiers": 0]], "JSON": [["destinationuid": "COPY", "modifiers": 0]]],
    ]
    return Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/json.workflow"))
}

@Test func jsonConfigSetsTheArgumentAndTheNextObjectsConfig() {
    let workflow = jsonWorkflow(#"{"alfredworkflow": {"arg": "{query}", "config": {"clipboardtext": "{var:shortcut} on {query}"}}}"#)
    #expect(workflow.steps(after: "KW", argument: "a.mov", variables: workflow.variables) == [.copy("Make GIF on a.mov")])
}

@Test func jsonConfigSetsVariablesAndKeepsTheArgumentWithoutArg() {
    let workflow = jsonWorkflow(#"{"alfredworkflow": {"variables": {"who": "{query}"}, "config": {"clipboardtext": "{var:who}"}}}"#)
    // The override is the filled text, then Copy fills it again with the new variable.
    #expect(workflow.steps(after: "KW", argument: "ada") == [.copy("ada")])
    let arg = jsonWorkflow(#"{"alfredworkflow": {"arg": ["one", "two"]}}"#)
    #expect(arg.steps(after: "KW", argument: "x") == [.copy("one\ttwo")])
}

@Test func aQuoteInTheTextKeepsTheJSONWhole() {
    let workflow = jsonWorkflow(#"{"alfredworkflow": {"arg": "said {query}"}}"#)
    #expect(workflow.steps(after: "KW", argument: #""hi"\ there"#) == [.copy(#"said "hi"\ there"#)])
}

@Test func jsonThatDoesNotParseIsNamed() {
    #expect(jsonWorkflow("{nope").steps(after: "KW", argument: "x") == [.unsupported("utility.json with JSON that does not parse")])
    #expect(jsonWorkflow(#"{"other": 1}"#).steps(after: "KW", argument: "x") == [.unsupported("utility.json with JSON that does not parse")])
}
