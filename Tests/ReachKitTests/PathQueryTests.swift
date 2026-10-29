import Testing
@testable import ReachKit

@Test("A query that starts with ~/ or / is a path")
func pathKind() {
    #expect(QueryKind("~/") == .path(PathQuery("~/")!))
    #expect(QueryKind("/Applications/Saf") == .path(PathQuery("/Applications/Saf")!))
    #expect(QueryKind("~") == .normal("~"))
    #expect(QueryKind("open ~/x") == .files(FileQuery(.open, "~/x")))
    #expect(QueryKind("~/").text == "")
}

@Test("The folder ends at the last slash; the rest filters it")
func pathParts() throws {
    let query = try #require(PathQuery("~/Developer/Re"))
    #expect(query.folder == "~/Developer/")
    #expect(query.name == "Re")
    #expect(query.expandedFolder(home: "/Users/sam") == "/Users/sam/Developer/")
    #expect(query.entering("Reach") == "~/Developer/Reach/")
}

@Test("← drops the typed name, then goes up one folder", arguments: [
    ("~/Developer/Re", "~/Developer/"),
    ("~/Developer/", "~/"),
    ("~/", "/Users/"),
    ("/Users/", "/"),
    ("/", "/"),
    ("/Ap", "/"),
])
func back(_ query: String, expected: String) throws {
    #expect(try #require(PathQuery(query)).back(home: "/Users/sam") == expected)
}
