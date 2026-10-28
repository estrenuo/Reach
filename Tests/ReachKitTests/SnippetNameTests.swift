import Testing
@testable import ReachKit

@Test("Clean names", arguments: [
    ("Email signature", "Email signature"),
    ("  Email   signature \n", "Email signature"),
    ("", "New Snippet"),
    ("   ", "New Snippet"),
])
func cleans(_ input: String, expected: String) {
    #expect(SnippetName.clean(input) == expected)
}
