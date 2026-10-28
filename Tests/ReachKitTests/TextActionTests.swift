import Testing
@testable import ReachKit

@Test("Selected text gets Large Type and Copy as Plain Text, filtered by typing")
func textActions() {
    #expect(TextAction.filtered(by: "") == [.largeType, .copyPlainText])
    #expect(TextAction.filtered(by: "large") == [.largeType])
    #expect(TextAction.filtered(by: "zzz").isEmpty)
}

@Test("The header shows the first line, cut to fit")
func headline() {
    #expect(TextAction.headline("  Hello world \nsecond line") == "Hello world")
    #expect(TextAction.headline(String(repeating: "a", count: 80), limit: 10) == "aaaaaaaaa…")
}

@Test("The selection hotkey is ⌃⌥⌘\\ and valid")
func selectionHotkey() {
    #expect(KeyCombo.selection.display(key: "\\") == "⌃⌥⌘\\")
    #expect(KeyCombo.selection.isValid)
}
