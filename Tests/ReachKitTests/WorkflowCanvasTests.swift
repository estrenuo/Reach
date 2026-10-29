import Foundation
import Testing
@testable import ReachKit

@Test func cardsSitWhereUidataPutsThem() throws {
    let library = FileManager.default.temporaryDirectory.appending(path: "canvas-\(UUID().uuidString)")
    let workflow = try #require(Workflow(folder: try WorkflowFolder.addExample(into: library)))
    let positions = WorkflowLayout.positions(workflow)
    #expect(positions["HELLO"] == WorkflowPoint(x: 40, y: 80))
    #expect(positions["WEB"] == WorkflowPoint(x: 300, y: 160))
}

@Test func objectsWithoutPositionsGoInColumnsByDepth() {
    let workflow = Workflow(id: "w", folder: URL(fileURLWithPath: "/tmp/w"), name: "W",
                            objects: [WorkflowObject(uid: "A", type: ScriptFilter.type),
                                      WorkflowObject(uid: "B", type: Workflow.junction),
                                      WorkflowObject(uid: "C", type: Workflow.copyToClipboard)],
                            connections: ["A": [WorkflowConnection(to: "B")], "B": [WorkflowConnection(to: "C")]])
    let positions = WorkflowLayout.positions(workflow)
    #expect(positions["A"]?.x == 40 && positions["B"]?.x == 40 + WorkflowLayout.column
            && positions["C"]?.x == 40 + 2 * WorkflowLayout.column)
}

@Test func aCycleStillGetsALayout() {
    let workflow = Workflow(id: "w", folder: URL(fileURLWithPath: "/tmp/w"), name: "W",
                            objects: [WorkflowObject(uid: "A", type: Workflow.junction), WorkflowObject(uid: "B", type: Workflow.junction)],
                            connections: ["A": [WorkflowConnection(to: "B")], "B": [WorkflowConnection(to: "A")]])
    #expect(WorkflowLayout.positions(workflow).count == 2)
}

@Test func objectsHaveACategoryAndAName() {
    let filter = WorkflowObject(uid: "A", type: ScriptFilter.type, config: ["keyword": .string("gh")])
    #expect(filter.category == .input && filter.kindName == "Script Filter" && filter.summary == "gh")
    #expect(WorkflowObject(uid: "B", type: "alfred.workflow.output.somethingnew").kindName == "Somethingnew")
    #expect(WorkflowObject(uid: "C", type: "com.example").category == .other)
}
