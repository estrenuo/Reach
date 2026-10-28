import Foundation
import Testing
@testable import ReachKit

@Test("Folders have no Open With…; files have every action")
func availableActions() {
    #expect(!FileAction.available(isFolder: true).contains(.openWith))
    #expect(FileAction.available(isFolder: false) == FileAction.allCases)
}

@Test("Typing filters the actions, best match first")
func filterActions() {
    let all = FileAction.available(isFolder: false)
    #expect(FileAction.filtered(all, by: "") == all)
    #expect(FileAction.filtered(all, by: "copy") == [.copyPath, .copyFile])
    #expect(FileAction.filtered(all, by: "rev").first == .reveal)
    #expect(FileAction.filtered(all, by: "zzz").isEmpty)
}

/// Records what Move to Trash asked for. It has no way to delete anything.
private final class RecordingTrash: Trashing {
    var trashed: [URL] = []
    func trashItem(at url: URL, resultingItemURL: AutoreleasingUnsafeMutablePointer<NSURL?>?) throws {
        trashed.append(url)
        resultingItemURL?.pointee = URL(fileURLWithPath: "/Users/sam/.Trash/\(url.lastPathComponent)") as NSURL
    }
}

@Test("Move to Trash goes through trashItem, never a hard delete")
func trashUsesTrashItem() throws {
    let trash = RecordingTrash()
    let file = URL(fileURLWithPath: "/Users/sam/notes.txt")
    let result = try Trash.move(file, using: trash)
    #expect(trash.trashed == [file])
    #expect(result?.path == "/Users/sam/.Trash/notes.txt")
}

/// Refuses like a synced folder (a file provider) does.
private struct ProtectedFolder: Trashing {
    var code = CocoaError.Code.fileWriteNoPermission
    func trashItem(at url: URL, resultingItemURL: AutoreleasingUnsafeMutablePointer<NSURL?>?) throws {
        throw CocoaError(code)
    }
}

@Test("A folder that refuses: the fallback trashes it instead")
func trashFallsBack() throws {
    var asked: [URL] = []
    let file = URL(fileURLWithPath: "/Users/sam/Desktop/shot.png")
    try Trash.move(file, using: ProtectedFolder()) { asked.append($0) }
    #expect(asked == [file])
}

@Test("Other errors are not hidden by the fallback")
func trashOtherErrors() {
    var asked = 0
    #expect(throws: CocoaError.self) {
        try Trash.move(URL(fileURLWithPath: "/nope"), using: ProtectedFolder(code: .fileNoSuchFile)) { _ in asked += 1 }
    }
    #expect(asked == 0)
}
