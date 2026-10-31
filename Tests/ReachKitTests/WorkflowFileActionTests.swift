import Foundation
import Testing
import UniformTypeIdentifiers
@testable import ReachKit

/// File Action triggers as Alfred writes them (S-050): a name, UTIs, and
/// whether they take several files.
private func fileActionWorkflow() -> Workflow {
    let plist: [String: Any] = [
        "name": "Images",
        "objects": [
            ["uid": "OPT", "type": WorkflowFileAction.type, "config": [
                "name": "Optimize Images", "acceptsmulti": 1, "filetypes": ["public.png", "public.jpeg", "public.folder"],
            ]],
            ["uid": "INFO", "type": WorkflowFileAction.type, "config": [
                "name": "Bundle Identifier Information", "acceptsmulti": 0, "filetypes": ["com.apple.application-bundle"],
            ]],
            ["uid": "ANY", "type": WorkflowFileAction.type, "config": ["name": "Rename", "acceptsmulti": 0, "filetypes": [String]()]],
            ["uid": "COPY", "type": Workflow.copyToClipboard, "config": ["clipboardtext": "got {query}"]],
        ],
        "connections": ["OPT": [["destinationuid": "COPY", "modifiers": 0]]],
    ]
    return Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/images.workflow"))
}

private let png = URL(fileURLWithPath: "/tmp/a.png")
private let jpeg = URL(fileURLWithPath: "/tmp/b.jpeg")
private let text = URL(fileURLWithPath: "/tmp/c.txt")
private let app = URL(fileURLWithPath: "/Applications/Safari.app")

/// By extension only, so the tests need no files on disk.
private func byExtension(_ url: URL, _ identifier: String) -> Bool {
    guard let wanted = UTType(identifier), let type = UTType(filenameExtension: url.pathExtension) else { return false }
    return type.conforms(to: wanted)
}

@Test func fileActionsAreReadWithTheirTypes() {
    let actions = fileActionWorkflow().fileActions
    #expect(actions.map(\.uid) == ["OPT", "INFO", "ANY"])
    #expect(actions[0] == WorkflowFileAction(uid: "OPT", name: "Optimize Images",
                                             fileTypes: ["public.png", "public.jpeg", "public.folder"], acceptsMany: true))
    #expect(!actions[1].acceptsMany && actions[2].fileTypes.isEmpty)
}

@Test func aFileActionShowsOnlyForItsTypes() {
    let actions = fileActionWorkflow().fileActions
    #expect(actions[0].accepts([png], conforms: byExtension))
    #expect(actions[0].accepts([png, jpeg], conforms: byExtension))
    #expect(!actions[0].accepts([png, text], conforms: byExtension))
    #expect(!actions[0].accepts([text], conforms: byExtension))
    #expect(actions[1].accepts([app]) && !actions[1].accepts([png]))
    #expect(actions[2].accepts([text], conforms: byExtension))
    #expect(!actions[2].accepts([], conforms: byExtension))
}

@Test func aFileActionForOneFileHidesForSeveral() {
    let actions = fileActionWorkflow().fileActions
    #expect(!actions[2].accepts([png, text], conforms: byExtension))
    #expect(!actions[1].accepts([app, app], conforms: byExtension))
}

@Test func theFilesArePassedTabSeparated() {
    #expect(WorkflowFileAction.argument(for: [png]) == "/tmp/a.png")
    #expect(WorkflowFileAction.argument(for: [png, jpeg]) == "/tmp/a.png\t/tmp/b.jpeg")
    #expect(fileActionWorkflow().steps(after: "OPT", argument: "/tmp/a.png") == [.copy("got /tmp/a.png")])
}

@Test func aRealFileConformsByWhatIsOnDisk() throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: "reach-fa-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    #expect(WorkflowFileAction.conforms(folder, "public.folder"))
    #expect(WorkflowFileAction.conforms(png, "public.image"))
    #expect(!WorkflowFileAction.conforms(text, "public.image"))
    #expect(!WorkflowFileAction.conforms(text, "not a uti"))
}
