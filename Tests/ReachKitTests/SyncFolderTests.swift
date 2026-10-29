import Foundation
import Testing
@testable import ReachKit

private func temporaryFolder() -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "reach-sync-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func settingsSnippetsThemesAndWorkflowsLiveUnderTheFolder() throws {
    let folder = temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let sync = SyncFolder(folder: folder)
    let work = SnippetLibrary.Collection(id: UUID(), name: "Work", createdAt: Date(timeIntervalSince1970: 0))
    let library = SnippetLibrary(collections: [work], snippets: [
        .init(id: UUID(), name: "Signature", keyword: "sig", text: "Sander", createdAt: Date(timeIntervalSince1970: 60), collection: work.id),
    ])
    #expect(sync.modified == nil)
    try sync.write(preferences: ["launcher.theme": "dark", "webSearch.searches": Data([1, 2])], snippets: library)

    for file in [sync.preferences, sync.snippets, sync.workflows] {
        #expect(file.path.hasPrefix(folder.path))
        #expect(FileManager.default.fileExists(atPath: file.path))
    }
    #expect(sync.readPreferences()["launcher.theme"] as? String == "dark")
    #expect(sync.readSnippets() == library)
    #expect(sync.modified != nil)
}

@Test func settingsOfThisMacStayOutOfTheFolder() throws {
    let folder = temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let sync = SyncFolder(folder: folder)
    try sync.write(preferences: ["sync.folder": "/Users/a", "NSWindow Frame main": "0 0 1 1", "hotkey": "space"],
                   snippets: SnippetLibrary())
    #expect(sync.readPreferences().keys.sorted() == ["hotkey"])
}

@Test func aNewerFolderIsReadAndOtherwiseThisMacWrites() {
    let then = Date(timeIntervalSince1970: 1000)
    #expect(SyncFolder.step(folderModified: nil, lastSynced: then) == .write)
    #expect(SyncFolder.step(folderModified: then, lastSynced: nil) == .read)
    #expect(SyncFolder.step(folderModified: then.addingTimeInterval(60), lastSynced: then) == .read)
    #expect(SyncFolder.step(folderModified: then, lastSynced: then) == .write)
}

@Test func readingTheFolderAddsUpdatesAndRemovesSnippetsById() {
    let (a, b, c) = (UUID(), UUID(), UUID())
    let changes = SnippetLibrary.changes(from: [a, b], to: [b, c])
    #expect(changes.insert == [c])
    #expect(changes.update == [b])
    #expect(changes.delete == [a])
}
