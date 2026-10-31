import Foundation
import Testing
@testable import ReachKit

/// An Alfred workflow with a Keyword input that sends its text on to Run
/// Script and Open URL, the way most workflows start.
private func keywordWorkflow(keyword: String = "yt", configured: [String: String] = [:]) -> Workflow {
    let plist: [String: Any] = [
        "name": "YouTube",
        "variables": ["kw": "tube"],
        "userconfigurationconfig": [["variable": "keyword", "label": "Keyword", "type": "textfield",
                                     "config": ["default": "yts", "required": false]]],
        "objects": [
            ["uid": "KW", "type": KeywordInput.type, "config": [
                "keyword": keyword, "withspace": true, "argumenttype": 0,
                "text": "Search YouTube for '{query}'", "subtext": "Opens in the browser",
            ]],
            ["uid": "URL", "type": Workflow.openURL, "config": ["url": "https://youtube.com/results?q={query}"]],
            ["uid": "SH", "type": Workflow.runScript, "config": ["script": "echo $1", "type": 0, "scriptargtype": 1]],
        ],
        "connections": ["KW": [
            ["destinationuid": "URL", "modifiers": 0],
            ["destinationuid": "SH", "modifiers": WorkflowConnection.command],
        ]],
    ]
    var workflow = Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/yt.workflow"))
    workflow.configuration = configured
    return workflow
}

@Test func aKeywordInputIsReadFromInfoPlist() {
    let workflow = keywordWorkflow()
    #expect(workflow.keywordInputs == [KeywordInput(uid: "KW", keyword: "yt", title: "Search YouTube for '{query}'",
                                                    subtext: "Opens in the browser")])
    #expect(workflow.keywords == ["yt"])
    #expect(workflow.scriptFilters.isEmpty)
}

@Test func aKeywordInputMatchesLikeAScriptFilter() {
    let input = KeywordInput(uid: "a", keyword: "yt", title: "Search for {query}")
    #expect(input.match("y") == .keyword)
    #expect(input.match("yt") == .needsText)
    #expect(input.match("yt cats") == .run("cats"))
    #expect(input.match("ytcats") == nil)
    #expect(input.title(for: "cats") == "Search for cats")
    #expect(KeywordInput(uid: "b", keyword: "lock", argument: .none).match("lock") == .run(""))
}

@Test func theTypedTextGoesOnToWhatIsConnectedToTheKeyword() {
    let workflow = keywordWorkflow()
    #expect(workflow.steps(after: "KW", argument: "cats dogs") == [.open("https://youtube.com/results?q=cats%20dogs")])
    let script = workflow.steps(after: "KW", argument: "cats", modifiers: WorkflowConnection.command)
    guard case .run(let command, let then, _) = script.first else {
        Issue.record("⌘ runs the script")
        return
    }
    #expect(command.arguments.last == "cats" && then == "SH")
}

@Test func aKeywordFromAVariableOrTheConfigurationIsFilledIn() {
    #expect(keywordWorkflow(keyword: "{var:kw}").keywords == ["tube"])
    #expect(keywordWorkflow(keyword: "{var:keyword}").keywords == ["yts"])
    #expect(keywordWorkflow(keyword: "{var:keyword}", configured: ["keyword": "y"]).keywords == ["y"])
    #expect(keywordWorkflow(keyword: "{var:missing}").keywords.isEmpty)
}
