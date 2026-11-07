import Foundation
import Testing
@testable import ReachKit

/// S-062: lines added, removed and changed on the canvas.
private func example() throws -> URL {
    let library = FileManager.default.temporaryDirectory.appending(path: "connect-\(UUID().uuidString)", directoryHint: .isDirectory)
    let folder = try WorkflowFolder.addExample(into: library)
    // A Keyword and a Hotkey with no lines yet, and a key Reach does not know.
    try WorkflowFolder.update(folder) { plist in
        plist["objects"] = (plist["objects"] as! [[String: Any]]) + [
            ["uid": "KW", "type": KeywordInput.type, "config": ["keyword": "kw", "argumenttype": 2, "text": "Keyword"]],
            ["uid": "HK", "type": WorkflowHotkey.type, "config": ["argument": 0]],
            ["uid": "LT", "type": Workflow.largeType, "config": [:]],
        ]
        plist["somethingnew"] = ["kept": Date(timeIntervalSince1970: 1)]
    }
    return folder
}

private func read(_ folder: URL) throws -> NSDictionary {
    let data = try Data(contentsOf: folder.appending(path: Workflow.infoFile))
    return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? NSDictionary)
}

/// Every key but `connections` is equal, and so are the lines of every object but `from`.
private func onlyLinesOf(_ from: String, changed before: NSDictionary, _ after: NSDictionary) {
    for key in before.allKeys as! [String] where key != "connections" {
        #expect((before[key] as AnyObject).isEqual(after[key]), "\(key) changed")
    }
    let others = { (plist: NSDictionary) in ((plist["connections"] as? [String: Any]) ?? [:]).filter { $0.key != from } as NSDictionary }
    #expect(others(before) == others(after))
}

@Test func aNewConnectionIsWrittenAsAlfredWritesOne() throws {
    let folder = try example()
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    let before = try read(folder)

    try WorkflowEdit.connect("KW", to: "COPY", folder: folder)

    let after = try read(folder)
    let lines = (after["connections"] as? [String: Any])?["KW"] as? [[String: Any]]
    #expect(lines?.count == 1)
    #expect(lines?.first?["destinationuid"] as? String == "COPY")
    #expect(lines?.first?["modifiers"] as? Int == 0)
    #expect(lines?.first?["vitoclose"] as? Bool == false)
    onlyLinesOf("KW", changed: before, after)
    // The new line is the one Workflow reads.
    #expect(Workflow(folder: folder)?.connections["KW"] == [WorkflowConnection(to: "COPY")])
}

@Test func aLoopIsRefused() throws {
    let folder = try example()
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    try WorkflowFolder.update(folder) { plist in
        plist["objects"] = (plist["objects"] as! [[String: Any]]) + [
            ["uid": "A", "type": Workflow.junction], ["uid": "B", "type": Workflow.argument],
        ]
        WorkflowEdit.insert(["destinationuid": "B", "modifiers": 0], from: "A", at: nil, in: &plist)
    }
    let bytes = try Data(contentsOf: folder.appending(path: Workflow.infoFile))
    #expect(throws: WorkflowRefusal.loop(kind: "Junction")) { try WorkflowEdit.connect("B", to: "A", folder: folder) }
    #expect(throws: WorkflowRefusal.itself) { try WorkflowEdit.connect("A", to: "A", folder: folder) }
    // A refused line leaves the file as it was.
    #expect(try Data(contentsOf: folder.appending(path: Workflow.infoFile)) == bytes)
}

@Test func kindsThatCannotConnectAreRefusedWithTheReason() throws {
    let folder = try example()
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    let workflow = try #require(Workflow(folder: folder))
    // An output into a trigger.
    #expect(WorkflowEdit.refusal(from: "WEB", to: "HK", in: workflow) == .intoTrigger)
    // An action into an input; a trigger into an input is fine, as in Alfred.
    #expect(WorkflowEdit.refusal(from: "WEB", to: "KW", in: workflow) == .intoInput)
    #expect(WorkflowEdit.refusal(from: "HK", to: "KW", in: workflow) == nil)
    // Nothing comes after Copy to Clipboard or Large Type.
    #expect(WorkflowEdit.refusal(from: "COPY", to: "WEB", in: workflow) == .afterEnd(kind: "Copy to Clipboard"))
    #expect(WorkflowEdit.refusal(from: "LT", to: "WEB", in: workflow)?.errorDescription == "Large Type ends a workflow: nothing comes after it.")
    // A line that is there already.
    #expect(WorkflowEdit.refusal(from: "HELLO", to: "COPY", in: workflow) == .connected)
    #expect(WorkflowRefusal.intoTrigger.errorDescription == "A trigger starts a workflow: nothing connects into it.")
}

@Test func aDisconnectRemovesOnlyThatLineAndUndoPutsItBack() throws {
    let folder = try example()
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    let before = try read(folder)
    let bytes = try Data(contentsOf: folder.appending(path: Workflow.infoFile))

    let removed = try #require(try WorkflowEdit.disconnect(WorkflowLine(from: "HELLO", to: "COPY"), folder: folder))
    #expect(removed.index == 0)
    #expect(Workflow(folder: folder)?.connections["HELLO"]?.map(\.to) == ["WEB"])
    onlyLinesOf("HELLO", changed: before, try read(folder))
    // A line that is not there changes nothing.
    #expect(try WorkflowEdit.disconnect(WorkflowLine(from: "HELLO", to: "COPY"), folder: folder) == nil)

    try WorkflowEdit.insert(removed.entry, from: "HELLO", at: removed.index, folder: folder)
    #expect(try Data(contentsOf: folder.appending(path: Workflow.infoFile)) == bytes)
}

@Test func theLastLineOfAnObjectTakesItsEntryWithIt() {
    var plist: [String: Any] = ["connections": ["A": [["destinationuid": "B", "modifiers": 0]]]]
    WorkflowEdit.disconnect(WorkflowLine(from: "A", to: "B"), in: &plist)
    #expect((plist["connections"] as? [String: Any])?.isEmpty == true)
}

@Test func aModifierChangeKeepsTheLinesOtherKeys() throws {
    let folder = try example()
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    let web = WorkflowLine(from: "HELLO", to: "WEB", modifiers: WorkflowConnection.command)
    let moved = try WorkflowEdit.setModifiers(WorkflowConnection.option, of: web, folder: folder)
    #expect(moved == WorkflowLine(from: "HELLO", to: "WEB", modifiers: WorkflowConnection.option))
    let line = Workflow(folder: folder)?.connections["HELLO"]?.first { $0.to == "WEB" }
    #expect(line?.modifiers == WorkflowConnection.option && line?.modifierSubtext == "Open a web search")
    // Back to none is refused while another line to WEB has none: two lines never share all three.
    var plist: [String: Any] = ["connections": ["A": [["destinationuid": "B", "modifiers": 0],
                                                      ["destinationuid": "B", "modifiers": WorkflowConnection.shift]]]]
    #expect(WorkflowEdit.setModifiers(0, of: WorkflowLine(from: "A", to: "B", modifiers: WorkflowConnection.shift), in: &plist) == nil)
}

/// S-062: Return follows a new line at once, because the steps come from the lines as read.
@Test func stepsFollowANewLineAtOnce() throws {
    let folder = try example()
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    #expect(try #require(Workflow(folder: folder)).steps(after: "KW", argument: "hi").isEmpty)

    try WorkflowEdit.connect("KW", to: "COPY", folder: folder)
    #expect(try #require(Workflow(folder: folder)).steps(after: "KW", argument: "hi") == [.copy("hi")])

    _ = try WorkflowEdit.disconnect(WorkflowLine(from: "KW", to: "COPY"), folder: folder)
    #expect(try #require(Workflow(folder: folder)).steps(after: "KW", argument: "hi").isEmpty)
}
