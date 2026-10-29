import Foundation
import Testing
@testable import ReachKit

private func tempLibrary() -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "reach-workflows-\(UUID().uuidString)", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func removingMovesTheWorkflowFolderToTheTrash() throws {
    let library = tempLibrary()
    let trash = tempLibrary()
    defer { try? FileManager.default.removeItem(at: library); try? FileManager.default.removeItem(at: trash) }
    let folder = try WorkflowFolder.addExample(into: library)
    var trashed: [URL] = []
    try WorkflowFolder.remove(folder) { url in
        trashed.append(url)
        try FileManager.default.moveItem(at: url, to: trash.appending(path: url.lastPathComponent))
    }
    #expect(trashed == [folder])
    #expect(!FileManager.default.fileExists(atPath: folder.path))
    #expect(Workflow(folder: trash.appending(path: folder.lastPathComponent))?.name == "Hello World")
}

@Test func switchingOffIsSavedInTheInfoPlist() throws {
    let library = tempLibrary()
    defer { try? FileManager.default.removeItem(at: library) }
    let folder = try WorkflowFolder.addExample(into: library)
    try WorkflowFolder.setDisabled(true, folder: folder)
    #expect(Workflow(folder: folder)?.disabled == true)
    #expect(Workflow(folder: folder)?.scriptFilters.first?.keyword == "hello")
    try WorkflowFolder.setDisabled(false, folder: folder)
    #expect(Workflow(folder: folder)?.disabled == false)
}

@Test func installingCopiesAWorkflowAndRefusesOtherFolders() throws {
    let library = tempLibrary()
    let elsewhere = tempLibrary()
    defer { try? FileManager.default.removeItem(at: library); try? FileManager.default.removeItem(at: elsewhere) }
    let source = try WorkflowFolder.addExample(into: elsewhere)
    let installed = try WorkflowFolder.install(from: source, into: library)
    #expect(installed.deletingLastPathComponent().standardizedFileURL == library.standardizedFileURL)
    #expect(installed.lastPathComponent.hasPrefix("user.workflow."))
    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(throws: WorkflowFolder.Failure.notAWorkflow) { try WorkflowFolder.install(from: library, into: elsewhere) }
}

@Test func theFilterFindsNameAuthorAndKeyword() {
    let workflow = Workflow(id: "w", folder: URL(fileURLWithPath: "/tmp/w"), name: "GitHub Repos", author: "Ada Lovelace", objects: [
        WorkflowObject(uid: "SF", type: ScriptFilter.type, config: ["keyword": .string("gh")]),
    ])
    #expect(WorkflowFolder.matches(workflow, filter: ""))
    #expect(WorkflowFolder.matches(workflow, filter: "rep"))
    #expect(WorkflowFolder.matches(workflow, filter: "love"))
    #expect(WorkflowFolder.matches(workflow, filter: "gh"))
    #expect(!WorkflowFolder.matches(workflow, filter: "hub"))
}
