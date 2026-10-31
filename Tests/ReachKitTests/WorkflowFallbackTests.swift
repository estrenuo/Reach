import Foundation
import Testing
@testable import ReachKit

/// Fallback Searches as Sander's workflows write them (S-052): a title, and a
/// line to a script filter whose keyword then shows with the text.
@Test func aFallbackIsReadWithItsTitleAndShowsTheKeywordWithTheText() {
    let plist: [String: Any] = [
        "name": "Shimmering Obsidian",
        "objects": [
            ["uid": "FB", "type": WorkflowFallback.type, "config": ["text": "Search Vault: '{query}'"]],
            ["uid": "BARE", "type": WorkflowFallback.type, "config": [String: Any]()],
            ["uid": "SF", "type": ScriptFilter.type, "config": ["keyword": "o", "title": "Search", "type": 0]],
        ],
        "connections": ["FB": [["destinationuid": "SF", "modifiers": 0]]],
    ]
    let workflow = Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/obsidian.workflow"))
    #expect(workflow.fallbacks.map(\.uid) == ["FB", "BARE"])
    #expect(workflow.fallbacks[0].title(for: "meeting", workflow: workflow.name) == "Search Vault: 'meeting'")
    #expect(workflow.fallbacks[1].title(for: "meeting", workflow: workflow.name) == "Search Shimmering Obsidian for 'meeting'")
    #expect(workflow.steps(after: "FB", argument: "meeting") == [.show("o meeting")])
}
