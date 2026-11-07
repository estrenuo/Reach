import Foundation
import Testing
@testable import ReachKit

private func example() throws -> URL {
    let library = FileManager.default.temporaryDirectory.appending(path: "edit-\(UUID().uuidString)", directoryHint: .isDirectory)
    return try WorkflowFolder.addExample(into: library)
}

private func plist(_ folder: URL) throws -> NSDictionary {
    let data = try Data(contentsOf: folder.appending(path: Workflow.infoFile))
    return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? NSDictionary)
}

@Test func aDropSnapsToTheGridAndStaysOnTheCanvas() {
    #expect(WorkflowEdit.snapped(WorkflowPoint(x: 123.4, y: 56)) == WorkflowPoint(x: 120, y: 60))
    #expect(WorkflowEdit.snapped(WorkflowPoint(x: -30, y: 4)) == WorkflowPoint(x: 0, y: 0))
}

@Test func aMoveChangesOnlyThatObjectsPosition() throws {
    let folder = try example()
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    // A note on the card, and a key Reach does not know, must survive.
    try WorkflowFolder.update(folder) { plist in
        var uidata = plist["uidata"] as! [String: Any]
        var hello = uidata["HELLO"] as! [String: Any]
        hello["note"] = "Start here"
        uidata["HELLO"] = hello
        plist["uidata"] = uidata
        plist["somethingnew"] = ["kept": Date(timeIntervalSince1970: 1)]
    }
    let before = try plist(folder)
    let bytesBefore = try Data(contentsOf: folder.appending(path: Workflow.infoFile))

    try WorkflowEdit.move("HELLO", to: WorkflowPoint(x: 203, y: 97), folder: folder)

    let after = try plist(folder)
    let hello = (after["uidata"] as? [String: Any])?["HELLO"] as? [String: Any]
    #expect(hello?["xpos"] as? Double == 200 && hello?["ypos"] as? Double == 100)
    #expect(hello?["note"] as? String == "Start here")
    // Every other key is equal, and so is the rest of uidata.
    for key in before.allKeys as! [String] where key != "uidata" {
        #expect((before[key] as AnyObject).isEqual(after[key]), "\(key) changed")
    }
    let otherBefore = (before["uidata"] as! [String: Any]).filter { $0.key != "HELLO" } as NSDictionary
    let otherAfter = (after["uidata"] as! [String: Any]).filter { $0.key != "HELLO" } as NSDictionary
    #expect(otherBefore == otherAfter)
    // Byte for byte: the file differs only in the two lines with the new numbers.
    let linesBefore = String(decoding: bytesBefore, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: false)
    let linesAfter = String(decoding: try Data(contentsOf: folder.appending(path: Workflow.infoFile)), as: UTF8.self)
        .split(separator: "\n", omittingEmptySubsequences: false)
    #expect(linesBefore.count == linesAfter.count)
    let changed = zip(linesBefore, linesAfter).filter { $0 != $1 }
    #expect(changed.count == 2 && changed.allSatisfy { $0.1.contains("<real>") })
}

@Test func theFileIsReplacedNotWrittenInPlace() throws {
    let folder = try example()
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    let url = folder.appending(path: Workflow.infoFile)
    let inode = { (try FileManager.default.attributesOfItem(atPath: url.path)[.systemFileNumber] as? Int) ?? 0 }
    let first = try inode()
    try WorkflowEdit.move("COPY", to: WorkflowPoint(x: 0, y: 0), folder: folder)
    // A safe save writes a temporary file and swaps it in: a half-written
    // info.plist is never what Alfred or Reach reads.
    #expect(try inode() != first)
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0 != Workflow.infoFile }
    #expect(leftovers.isEmpty)
}

@Test func aChangeOnDiskIsReadBeforeTheMove() throws {
    let folder = try example()
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    let read = try #require(Workflow(folder: folder))
    #expect(!WorkflowEdit.changedOnDisk(read))
    // Alfred renames the workflow after Reach read it.
    try waitASecond()
    try WorkflowFolder.update(folder) { $0["name"] = "Renamed in Alfred" }
    #expect(WorkflowEdit.changedOnDisk(read))
    try WorkflowEdit.move("WEB", to: WorkflowPoint(x: 400, y: 200), folder: folder)
    let now = try #require(Workflow(folder: folder))
    #expect(now.name == "Renamed in Alfred" && now.positions["WEB"] == WorkflowPoint(x: 400, y: 200))
}

/// File dates can be as coarse as a second; wait so a second write gets a new one.
private func waitASecond() throws { Thread.sleep(forTimeInterval: 1.05) }

@Test func anObjectWithoutUidataGetsAPlace() throws {
    var plist: [String: Any] = ["objects": [["uid": "NEW", "type": Workflow.junction]]]
    WorkflowEdit.move("NEW", to: WorkflowPoint(x: 31, y: 49), in: &plist)
    let entry = (plist["uidata"] as? [String: Any])?["NEW"] as? [String: Any]
    #expect(entry?["xpos"] as? Double == 30 && entry?["ypos"] as? Double == 50)
}
