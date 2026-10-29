import Testing
@testable import ReachKit

struct ClipboardMergeTests {
    @Test func separatorIsUsed() {
        #expect(ClipboardMerge.merged("Hello", "world", separator: .space) == "Hello world")
        #expect(ClipboardMerge.merged("Hello", "world", separator: .newline) == "Hello\nworld")
        #expect(ClipboardMerge.merged("Hello", "world", separator: .blankLine) == "Hello\n\nworld")
        #expect(ClipboardMerge.merged("Hello", "world", separator: .none) == "Helloworld")
        #expect(ClipboardMerge.Separator.allCases.map(\.title) == ["Separate with a Space", "Separate with a New Line",
                                                                    "Separate with a Blank Line", "No Separator"])
    }

    @Test func soundPlaysWhenEnabled() {
        #expect(ClipboardMerge.sound(enabled: true) == "Purr")
        #expect(ClipboardMerge.sound(enabled: false) == nil)
    }

    @Test func doubleTap() {
        var tap = ClipboardMerge.DoubleTap()
        // A third press starts over; 0.7 s apart is too slow.
        let presses = [10, 10.3, 10.5, 11.2, 11.4].map { tap.pressed(at: $0) }
        #expect(presses == [false, true, false, false, true])
        // Letting go of ⌘ in between: two separate copies.
        let first = tap.pressed(at: 20)
        tap.released()
        let second = tap.pressed(at: 20.2)
        #expect(!first && !second)
    }
}
