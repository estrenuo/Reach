import Foundation
import Testing
@testable import ReachKit

/// Replace as Sander's workflows use it (S-051): regular expressions with groups.
private func replace(_ config: [String: PlistValue]) -> WorkflowObject {
    WorkflowObject(uid: "R", type: Workflow.replace, config: config)
}

@Test func aRegularExpressionReplacesWithItsGroups() {
    let gallery = replace(["matchmode": .int(1), "matchstring": .string(#"https:\/\/alfred\.app\/workflows\/(.+?)\/(.+?)\/"#),
                           "replacestring": .string("alfred://gallery/workflow/$1/$2/")])
    #expect(WorkflowReplace.apply(to: "https://alfred.app/workflows/vitor/github/", gallery)
        == .success("alfred://gallery/workflow/vitor/github/"))
    let repo = replace(["matchmode": .int(1), "matchstring": .string(#".*github.com\/([^\/?]*\/[^\/?]*).*"#), "replacestring": .string("$1")])
    #expect(WorkflowReplace.apply(to: "https://github.com/estrenuo/Reach/pull/9", repo) == .success("estrenuo/Reach"))
    let newline = replace(["matchmode": .int(1), "matchstring": .string(#"\n$"#), "replacestring": .string("")])
    #expect(WorkflowReplace.apply(to: "note\n", newline) == .success("note"))
}

@Test func replaceHonoursCaseAndLinesAndPlainText() {
    #expect(WorkflowReplace.apply(to: "Hello hello", replace(["matchmode": .int(1), "matchstring": .string("hello"),
                                                              "replacestring": .string("x"), "regexcaseinsensitive": .bool(true)]))
        == .success("x x"))
    #expect(WorkflowReplace.apply(to: "a\nb", replace(["matchmode": .int(1), "matchstring": .string("^b"),
                                                      "replacestring": .string("c"), "regexmultiline": .bool(true)]))
        == .success("a\nc"))
    #expect(WorkflowReplace.apply(to: "a.b.c", replace(["matchmode": .int(0), "matchstring": .string("."), "replacestring": .string("/")]))
        == .success("a/b/c"))
}

@Test func anUnknownModeOrABadExpressionIsNamed() {
    #expect(WorkflowReplace.apply(to: "x", replace(["matchmode": .int(7)])) == .failure(.init(kind: "utility.replace match mode 7")))
    if case .failure = WorkflowReplace.apply(to: "x", replace(["matchmode": .int(1), "matchstring": .string("(")])) {} else {
        Issue.record("a bad expression should fail")
    }
}

@Test func replaceSendsTheNewTextOn() {
    let plist: [String: Any] = [
        "name": "R",
        "objects": [
            ["uid": "KW", "type": KeywordInput.type, "config": ["keyword": "r"]],
            ["uid": "R", "type": Workflow.replace, "config": ["matchmode": 1, "matchstring": "-", "replacestring": " "]],
            ["uid": "COPY", "type": Workflow.copyToClipboard, "config": [:]],
        ],
        "connections": ["KW": [["destinationuid": "R", "modifiers": 0]], "R": [["destinationuid": "COPY", "modifiers": 0]]],
    ]
    #expect(Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/r.workflow")).steps(after: "KW", argument: "a-b") == [.copy("a b")])
}
