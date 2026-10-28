import Foundation
import Testing
@testable import ReachKit

private let report = URL(fileURLWithPath: "/Users/sam/report.pdf")
private let photo = URL(fileURLWithPath: "/Users/sam/photo.png")
private let notes = URL(fileURLWithPath: "/Users/sam/notes.txt")

@Test("⌥↑ adds an item, and takes it out again")
func bufferToggle() {
    var buffer = FileBuffer()
    buffer.toggle(report, at: 0)
    buffer.toggle(photo, at: 1)
    #expect(buffer.items == [report, photo])
    buffer.toggle(report, at: 2)
    #expect(buffer.items == [photo])
}

@Test("⌥↓ adds without taking out; an item is in the buffer once")
func bufferAdd() {
    var buffer = FileBuffer()
    buffer.add(report, at: 0)
    buffer.add(photo, at: 1)
    buffer.add(report, at: 2)
    #expect(buffer.items == [report, photo])
}

@Test("⌥← takes out the item added last, and says when there is none")
func bufferRemoveLast() {
    var buffer = FileBuffer()
    let none = buffer.removeLast(at: 0)
    #expect(!none)
    buffer.add(report, at: 0)
    buffer.add(photo, at: 1)
    buffer.add(notes, at: 2)
    let removed = buffer.removeLast(at: 3)
    #expect(removed)
    #expect(buffer.items == [report, photo])
}

@Test("An action empties the buffer")
func bufferClear() {
    var buffer = FileBuffer()
    buffer.add(report, at: 0)
    buffer.add(photo, at: 1)
    buffer.clear()
    #expect(buffer.isEmpty)
}

@Test("The buffer goes stale after 5 minutes unused; using it resets the clock")
func bufferStale() {
    var buffer = FileBuffer()
    #expect(!buffer.isStale(at: 10_000))
    buffer.add(report, at: 100)
    #expect(!buffer.isStale(at: 100 + 299))
    #expect(buffer.isStale(at: 100 + 301))
    buffer.touch(at: 400)
    #expect(!buffer.isStale(at: 600))
}

@Test("Several items skip the actions that are for one item")
func manyItemActions() {
    let many = FileAction.available(isFolder: false, many: true)
    #expect(!many.contains(.browse) && !many.contains(.terminal) && !many.contains(.quickLook))
    #expect(many.contains(.openWith) && many.contains(.trash) && many.contains(.copyPath))
    #expect(!FileAction.available(isFolder: true, many: true).contains(.openWith))
}
