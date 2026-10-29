import Foundation
import Testing
@testable import ReachKit

@Test func readsTheScriptFilterJSONFormat() throws {
    let json = """
    {"rerun": 1.5, "variables": {"page": 2},
     "items": [
      {"uid": "r1", "title": "reach", "subtitle": "A launcher", "arg": "https://github.com/a/reach",
       "icon": {"type": "fileicon", "path": "/Applications/Safari.app"}, "autocomplete": "reach",
       "mods": {"cmd": {"arg": "a/reach", "subtitle": "Copy the name"}, "alt": {"valid": false, "subtitle": "No"}},
       "text": {"copy": "a/reach", "largetype": "REACH"}, "quicklookurl": "https://github.com"},
      {"title": "Not yet", "valid": false, "autocomplete": "more "},
      {"title": "Two", "arg": ["one", "two"], "valid": "yes", "uid": 7}
     ]}
    """
    let output = try ScriptFilterOutput.parse(Data(json.utf8))
    #expect(output.items.count == 3)
    #expect(output.rerun == 1.5)
    #expect(output.variables == ["page": "2"])
    let first = output.items[0]
    #expect(first.uid == "r1" && first.title == "reach" && first.subtitle == "A launcher")
    #expect(first.argument == "https://github.com/a/reach" && first.valid)
    #expect(first.icon == .init(type: "fileicon", path: "/Applications/Safari.app"))
    #expect(first.mod("cmd")?.arg == ["a/reach"] && first.mod("cmd")?.subtitle == "Copy the name")
    #expect(first.mod("alt")?.valid == false)
    #expect(first.text?.largetype == "REACH")
    #expect(!output.items[1].valid && output.items[1].autocomplete == "more ")
    #expect(output.items[2].arg == ["one", "two"] && output.items[2].valid && output.items[2].uid == "7")
}

@Test func skipsTextBeforeTheJSONAndSaysWhatIsWrong() throws {
    let output = try ScriptFilterOutput.parse(Data("debug line\n{\"items\": []}".utf8))
    #expect(output.items.isEmpty)
    #expect(throws: ScriptFilterOutput.Failure.empty) { try ScriptFilterOutput.parse(Data()) }
    #expect(throws: ScriptFilterOutput.Failure.self) { try ScriptFilterOutput.parse(Data("<items/>".utf8)) }
}

@Test func theKeywordDecidesWhenTheScriptRuns() {
    let script = ScriptSource(language: .bash, text: "echo")
    let required = ScriptFilter(uid: "a", keyword: "gh", script: script)
    #expect(required.match("g") == .keyword)
    #expect(required.match("gh") == .needsText)
    #expect(required.match("gh ") == .needsText)
    #expect(required.match("GH reach app") == .run("reach app"))
    #expect(required.match("ghost") == nil)
    #expect(required.match("other") == nil)

    let optional = ScriptFilter(uid: "b", keyword: "gh", withSpace: false, argument: .optional, script: script)
    #expect(optional.match("gh") == .run(""))
    #expect(optional.match("ghreach") == .run("reach"))
    let none = ScriptFilter(uid: "c", keyword: "gh", argument: .none, script: script)
    #expect(none.match("gh") == .run(""))
    #expect(none.match("gh x") == nil)
}

@Test func theTextReachesTheScriptAsArgumentOrInPlaceOfQuery() {
    let folder = URL(fileURLWithPath: "/tmp/wf")
    let argv = ScriptSource(language: .zsh, text: "echo $1").command(query: "a b", folder: folder)
    #expect(argv == ScriptCommand(executable: "/bin/zsh", arguments: ["-c", "echo $1", "zsh", "a b"], directory: folder))
    let inline = ScriptSource(language: .bash, text: "echo \"{query}\"", passesArgument: false, escaping: 4 | 32 | 64)
        .command(query: "say \"$HOME\"", folder: folder)
    #expect(inline?.arguments == ["-c", "echo \"say \\\"\\$HOME\\\"\"", "bash"])
    let file = ScriptSource(language: .file, file: "run.sh").command(query: "x", folder: folder)
    #expect(file?.executable == "/tmp/wf/run.sh" && file?.arguments == ["x"])
    #expect(ScriptSource(language: nil, text: "<?php").command(query: "", folder: folder) == nil)
}

@Test func readsAWorkflowFromItsInfoPlist() {
    let plist: [String: Any] = [
        "bundleid": "com.example.gh", "name": "GitHub", "createdby": "Sander", "version": "1.2",
        "variables": ["token": "abc"], "variablesdontexport": ["token"],
        "objects": [
            ["uid": "SF", "type": ScriptFilter.type, "config": [
                "keyword": "gh", "withspace": true, "argumenttype": 0, "title": "Search GitHub",
                "runningsubtext": "Searching…", "script": "./search.sh", "type": 0, "scriptargtype": 1,
            ]],
            ["uid": "URL", "type": Workflow.openURL, "config": ["url": "{query}"]],
            ["uid": "COPY", "type": Workflow.copyToClipboard, "config": ["clipboardtext": "{query} by {var:token}"]],
        ],
        "connections": ["SF": [
            ["destinationuid": "URL", "modifiers": 0],
            ["destinationuid": "COPY", "modifiers": WorkflowConnection.command, "modifiersubtext": "Copy"],
        ]],
    ]
    let workflow = Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/Workflows/user.workflow.ABC"))
    #expect(workflow.id == "user.workflow.ABC" && workflow.name == "GitHub" && workflow.author == "Sander")
    #expect(workflow.variables == ["token": "abc"] && workflow.dontExport == ["token"])
    let filter = try! #require(workflow.scriptFilters.first)
    #expect(filter.keyword == "gh" && filter.placeholder == "Search GitHub" && filter.waitingText == "Searching…")

    #expect(workflow.steps(after: "SF", argument: "https://github.com") == [.open("https://github.com")])
    #expect(workflow.steps(after: "SF", argument: "x", modifiers: WorkflowConnection.command, variables: workflow.variables)
            == [.copy("x by abc")])
    let env = workflow.environment(data: URL(fileURLWithPath: "/d"), cache: URL(fileURLWithPath: "/c"))
    #expect(env["alfred_workflow_bundleid"] == "com.example.gh" && env["alfred_workflow_data"] == "/d/com.example.gh")
    #expect(env["token"] == "abc")
}

@Test func aFilterWithNothingConnectedOpensAURLOrPath() {
    let workflow = Workflow(id: "w", folder: URL(fileURLWithPath: "/tmp/w"), name: "W", objects: [
        WorkflowObject(uid: "SF", type: ScriptFilter.type, config: ["keyword": .string("w")]),
    ])
    #expect(workflow.steps(after: "SF", argument: "~/Documents") == [.open("~/Documents")])
    #expect(workflow.steps(after: "SF", argument: "just text").isEmpty)
}

@Test func reachFiltersTheRowsWhenTheWorkflowAsks() throws {
    let output = try ScriptFilterOutput.parse(Data("""
    {"items": [{"title": "Safari Tabs"}, {"title": "Mail", "match": "post letters"}, {"title": "Notes"}]}
    """.utf8))
    #expect(output.filtered(by: "saf").map(\.title) == ["Safari Tabs"])
    #expect(output.filtered(by: "let").map(\.title) == ["Mail"])
    #expect(output.filtered(by: "").count == 3)
}
