import Testing
@testable import ReachKit

@Test("Quick Look that is key and showing a file keeps the launcher's keyboard")
func handoverQuickLookKey() {
    let handover = KeyboardHandover()
    #expect(handover.launcherKeepsKey(quickLookIsKey: true, showing: true, at: 100))
    // Quick Look key but already closed: someone else's doing.
    #expect(!handover.launcherKeepsKey(quickLookIsKey: true, showing: false, at: 100))
}

@Test("Within a second of Quick Look opening or closing, a lost keyboard comes back")
func handoverGrace() {
    var handover = KeyboardHandover()
    handover.moved(at: 100)
    #expect(handover.launcherKeepsKey(quickLookIsKey: false, showing: false, at: 100.9))
    #expect(!handover.launcherKeepsKey(quickLookIsKey: false, showing: false, at: 101.1))
}

@Test("Before Quick Look ever moved, a lost keyboard means the launcher hides")
func handoverNeverMoved() {
    #expect(!KeyboardHandover().launcherKeepsKey(quickLookIsKey: false, showing: false, at: 0.5))
}
