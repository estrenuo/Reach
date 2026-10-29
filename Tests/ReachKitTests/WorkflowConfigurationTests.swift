import Foundation
import Testing
@testable import ReachKit

private func folderWithSettings() throws -> URL {
    let library = FileManager.default.temporaryDirectory.appending(path: "config-\(UUID().uuidString)")
    return try WorkflowFolder.addExample(into: library)
}

@Test func readsTheConfigurationFields() throws {
    let workflow = try #require(Workflow(folder: try folderWithSettings()))
    #expect(workflow.settings.map(\.variable) == ["greeting", "shout"])
    #expect(workflow.settings[0].kind == .textfield && workflow.settings[0].required && workflow.settings[0].defaultValue == "Hello")
    #expect(workflow.settings[1].kind == .checkbox && workflow.settings[1].defaultValue == "0")
}

@Test func valuesArePassedToScriptsAsEnvironmentVariables() throws {
    let folder = try folderWithSettings()
    let before = try #require(Workflow(folder: folder))
    let temp = FileManager.default.temporaryDirectory
    #expect(before.environment(data: temp, cache: temp)["greeting"] == "Hello")
    try WorkflowConfiguration.save(["greeting": "Hoi", "shout": "1"], settings: before.settings, in: folder)
    let after = try #require(Workflow(folder: folder))
    let environment = after.environment(data: temp, cache: temp)
    #expect(environment["greeting"] == "Hoi" && environment["shout"] == "1")
}

@Test func aDefaultValueIsNotSaved() throws {
    let folder = try folderWithSettings()
    let workflow = try #require(Workflow(folder: folder))
    try WorkflowConfiguration.save(["greeting": "Hello", "shout": "0"], settings: workflow.settings, in: folder)
    #expect(!FileManager.default.fileExists(atPath: folder.appending(path: WorkflowConfiguration.prefsFile).path))
}

@Test func anEmptyRequiredFieldIsMissing() throws {
    let workflow = try #require(Workflow(folder: try folderWithSettings()))
    #expect(WorkflowConfiguration.missing(workflow.settings, values: ["greeting": "  "]).map(\.variable) == ["greeting"])
    #expect(WorkflowConfiguration.missing(workflow.settings, values: ["greeting": "Hi"]).isEmpty)
}

@Test func popUpChoicesAreRead() {
    let value = PlistValue(["type": "popupbutton", "variable": "size", "label": "Size",
                            "config": ["default": "m", "pairs": [["Small", "s"], ["Medium", "m"]]]] as [String: Any])!
    let setting = WorkflowSetting(value)
    #expect(setting?.options.map(\.value) == ["s", "m"] && setting?.defaultValue == "m")
}
