import Foundation
import Testing
@testable import ReachKit

/// Tag Finder's Grid View (S-053): JSON Config sets the columns, then a script file lists the files.
private func gridWorkflow(inputType: Int = 1) -> Workflow {
    let plist: [String: Any] = [
        "name": "Tag Finder",
        "objects": [
            ["uid": "SF", "type": ScriptFilter.type, "config": ["keyword": "tag", "type": 0, "script": "echo"]],
            ["uid": "JSON", "type": Workflow.json, "config": ["json": #"{"alfredworkflow": {"arg": "{query}", "config": {"columncount": "{var:gridColumns}"}}}"#]],
            ["uid": "GRID", "type": Workflow.grid, "config": [
                "columncount": 6, "filterable": true, "inputfile": "getTaggedFiles.sh", "inputtype": inputType, "loadingtext": "",
            ]],
            ["uid": "OPEN", "type": Workflow.openFile, "config": [:]],
        ],
        "variables": ["gridColumns": "4"],
        "connections": [
            "SF": [["destinationuid": "JSON", "modifiers": 0]],
            "JSON": [["destinationuid": "GRID", "modifiers": 0]],
            "GRID": [["destinationuid": "OPEN", "modifiers": 0]],
        ],
    ]
    return Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/tags.workflow"))
}

@Test func aGridViewRunsItsScriptFileWithTheArgument() {
    let workflow = gridWorkflow()
    let steps = workflow.steps(after: "SF", argument: "Red", variables: workflow.variables)
    #expect(steps == [.grid(WorkflowGridRun(uid: "GRID", command: ScriptCommand(executable: "/tmp/tags.workflow/getTaggedFiles.sh",
                                                                                arguments: ["Red"], directory: workflow.folder),
                                            variables: ["gridColumns": "4"], filterable: true))])
}

@Test func aChosenGridItemGoesOnAlongTheGridsLines() {
    #expect(gridWorkflow().steps(after: "GRID", argument: "/Users/ada/a.pdf") == [.open("/Users/ada/a.pdf")])
}

@Test func anotherGridInputIsNamed() {
    #expect(gridWorkflow(inputType: 0).steps(after: "SF", argument: "Red") == [.unsupported("userinterface.grid with input type 0")])
}
