import Foundation
import Testing
@testable import ReachKit

/// A → B, A ⌘→ C, A → D, B → C, C → D, with D's list empty, plus keys Reach does not know.
private func sample() -> [String: Any] {
    func line(_ to: String, _ modifiers: Int = 0) -> [String: Any] {
        ["destinationuid": to, "modifiers": modifiers, "modifiersubtext": "", "vitoclose": false]
    }
    return [
        "name": "Sample", "bundleid": "com.example.sample", "somethingnew": ["kept": Date(timeIntervalSince1970: 1)],
        "objects": ["A", "B", "C", "D"].map { ["uid": $0, "type": Workflow.junction, "version": 1, "config": ["n": $0]] as [String: Any] },
        "connections": [
            "A": [line("B"), line("C", WorkflowConnection.command), line("D")],
            "B": [line("C")],
            "C": [line("D")],
            "D": [] as [Any],
        ],
        "uidata": [
            "A": ["xpos": 10, "ypos": 10],
            "B": ["xpos": 200, "ypos": 10, "note": "Second"],
            "C": ["xpos": 200, "ypos": 120, "colorindex": 3],
            "D": ["xpos": 400, "ypos": 60],
        ],
    ]
}

private func uids(_ plist: [String: Any]) -> [String] {
    (plist["objects"] as? [[String: Any]] ?? []).compactMap { $0["uid"] as? String }
}

private func targets(_ plist: [String: Any], _ source: String) -> [String]? {
    ((plist["connections"] as? [String: Any])?[source] as? [[String: Any]])?.compactMap { $0["destinationuid"] as? String }
}

@Test func deletingRemovesTheObjectsTheirLinesAndUidata() {
    var plist = sample()
    let removed = WorkflowEdit.delete(["B", "C"], in: &plist)

    #expect(uids(plist) == ["A", "D"])
    let connections = plist["connections"] as? [String: Any] ?? [:]
    #expect(connections["B"] == nil && connections["C"] == nil)
    #expect(targets(plist, "A") == ["D"])
    #expect(targets(plist, "D") == [])
    #expect(Set((plist["uidata"] as? [String: Any] ?? [:]).keys) == ["A", "D"])
    #expect(removed.uids == ["B", "C"])
    #expect(removed.incoming.map { "\($0.source)\($0.index)" } == ["A0", "A1"])
}

@Test func deletingChangesNothingElse() {
    let before = sample()
    var plist = before
    WorkflowEdit.delete(["C"], in: &plist)
    for key in before.keys where !["objects", "connections", "uidata"].contains(key) {
        #expect((before[key] as AnyObject).isEqual(plist[key]), "\(key) changed")
    }
    // The other objects, lines and uidata are the same values as before.
    let keptObjects = (before["objects"] as! [[String: Any]]).filter { $0["uid"] as? String != "C" } as NSArray
    #expect(keptObjects.isEqual(plist["objects"]))
    let uidata = (before["uidata"] as! [String: Any]).filter { $0.key != "C" } as NSDictionary
    #expect(uidata.isEqual(plist["uidata"]))
    let lines = (plist["connections"] as! [String: Any])
    #expect(((before["connections"] as! [String: Any])["D"] as AnyObject).isEqual(lines["D"]))
    #expect(targets(plist, "A") == ["B", "D"] && targets(plist, "B") == [])
    let modifiers = ((lines["A"] as? [[String: Any]])?.first)?["modifiers"] as? Int
    #expect(modifiers == 0)
}

@Test func restorePutsEveryPieceBackWhereItWas() {
    let before = sample()
    var plist = before
    let removed = WorkflowEdit.delete(["B", "C"], in: &plist)
    WorkflowEdit.restore(removed, in: &plist)
    #expect((before as NSDictionary).isEqual(plist as NSDictionary))
    #expect(uids(plist) == ["A", "B", "C", "D"])
    #expect(targets(plist, "A") == ["B", "C", "D"])
}

@Test func anUnknownUidChangesNothing() {
    let before = sample()
    var plist = before
    let removed = WorkflowEdit.delete(["NOPE"], in: &plist)
    #expect(removed.objects.isEmpty && removed.incoming.isEmpty && removed.uidata.isEmpty)
    #expect((before as NSDictionary).isEqual(plist as NSDictionary))
}

@Test func deletingFromAFolderKeepsTheRestOfInfoPlist() throws {
    let library = FileManager.default.temporaryDirectory.appending(path: "delete-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: library) }
    let folder = try WorkflowFolder.addExample(into: library)
    let url = folder.appending(path: Workflow.infoFile)
    let read = { try #require(try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? NSDictionary) }
    let before = try read()

    let removed = try WorkflowEdit.delete(["COPY", "WEB"], folder: folder)
    let workflow = try #require(Workflow(folder: folder))
    #expect(workflow.objects.map(\.uid) == ["HELLO"])
    #expect(workflow.connections["HELLO"]?.isEmpty == true)
    #expect(workflow.positions.keys.sorted() == ["HELLO"])
    let after = try read()
    for key in before.allKeys as! [String] where !["objects", "connections", "uidata"].contains(key) {
        #expect((before[key] as AnyObject).isEqual(after[key]), "\(key) changed")
    }

    try WorkflowEdit.restore(removed, folder: folder)
    #expect(try read() == before)
}

@Test func theUndoNameCountsTheObjects() {
    #expect(WorkflowEdit.deleteName(1) == "Delete Object")
    #expect(WorkflowEdit.deleteName(2) == "Delete 2 Objects")
}
