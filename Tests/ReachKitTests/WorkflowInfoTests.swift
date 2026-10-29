import Foundation
import Testing
@testable import ReachKit

@Suite struct WorkflowInfoTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "info-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "name": "GitHub", "version": "1.0",
            "variables": ["token": "secret", "user": "ada"],
            "variablesdontexport": ["token"],
        ]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: url.appending(path: Workflow.infoFile))
        try PropertyListSerialization.data(fromPropertyList: ["greeting": "Hoi"], format: .xml, options: 0)
            .write(to: url.appending(path: WorkflowConfiguration.prefsFile))
        return url
    }

    @Test func dontExportVariablesAreStrippedOnExport() throws {
        let source = try folder()
        let staging = FileManager.default.temporaryDirectory.appending(path: "stage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let staged = try WorkflowExport.stage(source, in: staging)
        let exported = try #require(Workflow(folder: staged))
        #expect(exported.variables == ["token": "", "user": "ada"])
        #expect(exported.dontExport == ["token"])
        #expect(!FileManager.default.fileExists(atPath: staged.appending(path: WorkflowConfiguration.prefsFile).path))
        // The installed copy keeps its value.
        #expect(Workflow(folder: source)?.variables["token"] == "secret")
    }

    @Test func savesAboutReadmeAndVariables() throws {
        let url = try folder()
        var info = WorkflowInfo(try #require(Workflow(folder: url)))
        #expect(info.variables.map(\.name) == ["token", "user"])
        #expect(info.variables.first?.dontExport == true)
        info.version = "1.1"
        info.readme = "Search **GitHub**."
        info.variables.append(WorkflowVariable(name: "org", value: "apple", dontExport: false))
        info.variables.append(WorkflowVariable(name: " ", value: "ignored"))
        info.variables[0].dontExport = false
        try WorkflowFolder.update(url) { info.apply(to: &$0) }
        let saved = try #require(Workflow(folder: url))
        #expect(saved.version == "1.1")
        #expect(saved.readme == "Search **GitHub**.")
        #expect(saved.variables == ["token": "secret", "user": "ada", "org": "apple"])
        #expect(saved.dontExport.isEmpty)
    }

    @Test func badNamesAreProblems() throws {
        var info = WorkflowInfo(try #require(Workflow(folder: try folder())))
        #expect(info.problems.isEmpty)
        info.variables.append(WorkflowVariable(name: "user", value: "x"))
        info.variables.append(WorkflowVariable(name: "1st key", value: "x"))
        #expect(info.problems.count == 2)
        #expect(WorkflowInfo.isValidName("api_key2"))
        #expect(!WorkflowInfo.isValidName("api-key"))
    }
}
