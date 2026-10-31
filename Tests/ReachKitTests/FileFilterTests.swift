import Foundation
import Testing
@testable import ReachKit

/// File Filters as Sander's workflows write them (S-051).
private func fileFilterWorkflow() -> Workflow {
    let fields: [[String: Any]] = ["kMDItemDisplayName", "kMDItemAlternateNames", "kMDItemFinderComment"].map {
        ["field": $0, "not": false, "split": true, "value": "{query}", "words": true]
    }
    let common: [String: Any] = ["anchorfields": true, "argumenttrimmode": 0, "argumenttype": 0, "daterange": 0, "fields": fields,
                                 "includesystem": false, "limit": 0, "scopes": [String](), "sortmode": 0]
    let plist: [String: Any] = [
        "name": "Files",
        "objects": [
            ["uid": "FOLDER", "type": FileFilter.type, "config": common.merging([
                "keyword": "newin", "withspace": false, "title": "Location for new folder", "types": ["public.folder"],
            ]) { _, new in new }],
            ["uid": "CODE", "type": FileFilter.type, "config": common.merging([
                "keyword": "{var:codef_keyword}", "withspace": true, "title": "Find and open", "types": [String](),
            ]) { _, new in new }],
            ["uid": "ODD", "type": FileFilter.type, "config": [
                "keyword": "odd", "sortmode": 2, "includesystem": true, "limit": 5, "scopes": ["/tmp"],
            ]],
            ["uid": "COPY", "type": Workflow.copyToClipboard, "config": [:]],
        ],
        "variables": ["codef_keyword": "codef"],
        "connections": ["FOLDER": [["destinationuid": "COPY", "modifiers": 0]]],
    ]
    return Workflow(plist: plist, folder: URL(fileURLWithPath: "/tmp/files.workflow"))
}

@Test func fileFiltersAreReadWithTheirKeywordTypesAndFields() {
    let filters = fileFilterWorkflow().fileFilters
    #expect(filters.map(\.keyword) == ["newin", "codef", "odd"])
    #expect(filters[0].types == ["public.folder"] && !filters[0].withSpace && filters[0].title == "Location for new folder")
    #expect(filters[0].fields == FileFilter.defaultFields && filters[0].unmapped.isEmpty)
    #expect(filters[1].withSpace && filters[1].types.isEmpty)
    #expect(filters[2].scopes == ["/tmp"] && filters[2].limit == 5 && filters[2].unmapped == ["sortmode 2", "includesystem"])
    #expect(fileFilterWorkflow().keywords.contains("codef"))
}

@Test func theTypedTextMatchesAnyFieldAtWordStartsWithinTheTypes() {
    let filter = fileFilterWorkflow().fileFilters[0]
    #expect(filter.predicate(for: "q3 rep") == #"((kMDItemDisplayName == "q3*"cdw && kMDItemDisplayName == "rep*"cdw)"#
        + #" || (kMDItemAlternateNames == "q3*"cdw && kMDItemAlternateNames == "rep*"cdw)"#
        + #" || (kMDItemFinderComment == "q3*"cdw && kMDItemFinderComment == "rep*"cdw))"#
        + #" && (kMDItemContentTypeTree == "public.folder")"#)
    let any = fileFilterWorkflow().fileFilters[1]
    #expect(any.predicate(for: "a\"b") == #"(kMDItemDisplayName == "a\"b*"cdw || kMDItemAlternateNames == "a\"b*"cdw"#
        + #" || kMDItemFinderComment == "a\"b*"cdw)"#)
}

@Test func aFileFilterKeywordFollowsTheKeywordRules() {
    let filter = fileFilterWorkflow().fileFilters[0]
    #expect(filter.match("new") == .keyword)
    #expect(filter.match("newin") == .needsText)
    #expect(filter.match("newinDocs") == .run("Docs"))
    #expect(fileFilterWorkflow().fileFilters[1].match("codef reach") == .run("reach"))
}

@Test func returnOnAFileSendsItsPathOn() {
    #expect(fileFilterWorkflow().steps(after: "FOLDER", argument: "/Users/ada/Projects") == [.copy("/Users/ada/Projects")])
}
