import Foundation
import Testing
@testable import ReachKit

private func example() throws -> URL {
    let library = FileManager.default.temporaryDirectory.appending(path: "palette-\(UUID().uuidString)", directoryHint: .isDirectory)
    return try WorkflowFolder.addExample(into: library)
}

private func plist(_ folder: URL) throws -> NSDictionary {
    let data = try Data(contentsOf: folder.appending(path: Workflow.infoFile))
    return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? NSDictionary)
}

@Test func thePaletteListsEachKindOnceByCategory() {
    let types = WorkflowPalette.kinds.map(\.type)
    #expect(Set(types).count == types.count)
    let sections = WorkflowPalette.sections()
    #expect(sections.map(\.category) == [.trigger, .input, .action, .utility, .output])
    #expect(sections.flatMap(\.kinds).count == WorkflowPalette.kinds.count)
    for kind in WorkflowPalette.kinds {
        // Alfred's type names the category, and the card shows the palette's name.
        #expect(kind.type.hasPrefix("alfred.workflow.\(kind.category.rawValue)."), "\(kind.type)")
        #expect(WorkflowObject(uid: "X", type: kind.type).kindName == kind.name, "\(kind.type)")
        #expect(kind.version >= 1)
    }
    #expect(WorkflowPalette.sections()[1].kinds.map(\.name) == ["Keyword", "Script Filter", "File Filter"])
}

@Test func theVersionsAreAlfredsOwn() {
    // What Alfred 5.5 writes for each kind, read from its own workflows.
    let alfred: [String: Int] = [
        KeywordInput.type: 1, ScriptFilter.type: 3, FileFilter.type: 2, WorkflowHotkey.type: 2,
        Workflow.openURL: 1, Workflow.openFile: 3, Workflow.runScript: 2, Workflow.copyToClipboard: 3,
        Workflow.replace: 2, Workflow.junction: 1, Workflow.notification: 1,
    ]
    for (type, version) in alfred { #expect(WorkflowPalette.kind(type)?.version == version, "\(type)") }
}

@Test func thePaletteHasOnlyKindsReachRuns() {
    // Every action, utility and output, with its default config, runs after a keyword without "unsupported".
    let runs = WorkflowPalette.kinds.filter { [.action, .utility, .output].contains($0.category) }
    for kind in runs {
        let workflow = Workflow(plist: [
            "objects": [
                ["uid": "KW", "type": KeywordInput.type, "config": ["keyword": "k"]],
                kind.plist(uid: "NEW"),
            ],
            "connections": ["KW": [["destinationuid": "NEW", "modifiers": 0]]],
        ], folder: URL(fileURLWithPath: "/tmp/palette"))
        let steps = workflow.steps(after: "KW", argument: "text")
        #expect(!steps.contains { if case .unsupported = $0 { true } else { false } }, "\(kind.name): \(steps)")
    }
    // Triggers and inputs are the kinds Reach reads.
    let known: Set<String> = [KeywordInput.type, ScriptFilter.type, FileFilter.type, WorkflowHotkey.type, Workflow.externalTrigger,
                              WorkflowFallback.type, WorkflowFileAction.type, WorkflowUniversalAction.type]
    #expect(Set(WorkflowPalette.kinds.filter { [.trigger, .input].contains($0.category) }.map(\.type)) == known)
    // Kinds Reach does not run are not offered.
    for type in ["alfred.workflow.input.listfilter", "alfred.workflow.automation.task", "alfred.workflow.output.writefile",
                 "alfred.workflow.utility.transform", "alfred.workflow.trigger.remote"] {
        #expect(WorkflowPalette.kind(type) == nil)
    }
}

@Test func aFilterShowsTheMatchesInTheirCategories() {
    let open = WorkflowPalette.sections(filter: "open")
    #expect(open.map(\.category) == [.action])
    #expect(open[0].kinds.map(\.name) == ["Open URL", "Open File"])
    #expect(WorkflowPalette.sections(filter: "KEY").flatMap(\.kinds).map(\.name) == ["Keyword", "Dispatch Key Combo"])
    #expect(WorkflowPalette.sections(filter: "zzz").isEmpty)
}

@Test func aNewObjectGetsAFreshUIDItsDefaultConfigAndAPlace() throws {
    let uid = WorkflowEdit.newUID()
    #expect(UUID(uuidString: uid) != nil && uid == uid.uppercased())
    #expect(WorkflowEdit.newUID() != uid)

    let folder = try example()
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    let keyword = try #require(WorkflowPalette.kind(KeywordInput.type))
    try WorkflowEdit.add(keyword, uid: uid, at: WorkflowPoint(x: 433, y: 287), folder: folder)

    let workflow = try #require(Workflow(folder: folder))
    let added = try #require(workflow.object(uid))
    #expect(added.type == KeywordInput.type && added.config == keyword.config)
    #expect(workflow.positions[uid] == WorkflowPoint(x: 430, y: 290))
    let raw = try #require((try plist(folder)["objects"] as? [[String: Any]])?.first { $0["uid"] as? String == uid })
    #expect(raw["version"] as? Int == 1)
    #expect(workflow.objects.count == 4)
}

@Test func anAddChangesOnlyObjectsAndTheNewUidata() throws {
    let folder = try example()
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    try WorkflowFolder.update(folder) { $0["somethingnew"] = ["kept": Date(timeIntervalSince1970: 1)] }
    let before = try plist(folder)
    try WorkflowEdit.add(#require(WorkflowPalette.kind(Workflow.openURL)), uid: "NEW", at: WorkflowPoint(x: 0, y: 300), folder: folder)
    let after = try plist(folder)
    for key in before.allKeys as! [String] where !["objects", "uidata"].contains(key) {
        #expect((before[key] as AnyObject).isEqual(after[key]), "\(key) changed")
    }
    let objectsBefore = before["objects"] as! [NSDictionary]
    let objectsAfter = after["objects"] as! [NSDictionary]
    #expect(Array(objectsAfter.prefix(objectsBefore.count)) == objectsBefore)
    let uidataAfter = (after["uidata"] as! [String: Any]).filter { $0.key != "NEW" } as NSDictionary
    #expect(uidataAfter == before["uidata"] as! NSDictionary)
}

@Test func undoTakesTheAddedObjectAndItsLinesOff() throws {
    let folder = try example()
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    let before = try plist(folder)
    try WorkflowEdit.add(#require(WorkflowPalette.kind(Workflow.largeType)), uid: "NEW", at: WorkflowPoint(x: 500, y: 0), folder: folder)
    try WorkflowFolder.update(folder) { plist in
        var connections = plist["connections"] as! [String: Any]
        connections["HELLO"] = (connections["HELLO"] as! [[String: Any]]) + [["destinationuid": "NEW", "modifiers": 0]]
        connections["NEW"] = [["destinationuid": "COPY", "modifiers": 0]]
        plist["connections"] = connections
    }
    try WorkflowEdit.removeAdded("NEW", folder: folder)
    #expect(try plist(folder) == before)
}

@Test func returnPutsTheNewCardInAFreePlace() throws {
    let folder = try example()
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    let workflow = try #require(Workflow(folder: folder))
    // HELLO 40,80 · COPY 300,20 · WEB 300,160
    #expect(WorkflowEdit.freePlace(in: workflow) == WorkflowPoint(x: 40, y: 260))
    #expect(WorkflowEdit.freePlace(in: workflow, after: "COPY") == WorkflowPoint(x: 520, y: 20))
    // Right of HELLO is where COPY and WEB are: it goes down until it covers neither.
    let right = WorkflowEdit.freePlace(in: workflow, after: "HELLO")
    #expect(right.x == 260 && right.y == 280)
    let empty = Workflow(id: "e", folder: folder, name: "Empty")
    #expect(WorkflowEdit.freePlace(in: empty) == WorkflowPoint(x: 40, y: 40))
}
