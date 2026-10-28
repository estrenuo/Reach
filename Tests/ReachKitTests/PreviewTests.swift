import Testing
@testable import ReachKit

@Test("A quick ⇧ on its own is a tap")
func quickTap() {
    var tap = ShiftTap()
    tap.pressed(at: 10)
    let tapped = tap.released(at: 10.1)
    #expect(tapped)
}

@Test("⇧ held for a capital is not a tap")
func capital() {
    var tap = ShiftTap()
    tap.pressed(at: 10)
    tap.typed(at: 10.05)
    let tapped = tap.released(at: 10.1)
    #expect(!tapped)
}

@Test("A tap right after typing is a typist reaching for ⇧; a pause makes it count")
func afterTyping() {
    var tap = ShiftTap()
    tap.typed(at: 10)
    tap.pressed(at: 10.1)
    let tooSoon = tap.released(at: 10.2)
    #expect(!tooSoon)
    tap.pressed(at: 11)
    let afterPause = tap.released(at: 11.1)
    #expect(afterPause)
}

@Test("⇧ held a long time, or with ⌘, is not a tap")
func notATap() {
    var tap = ShiftTap()
    tap.pressed(at: 10)
    let held = tap.released(at: 12)
    #expect(!held)
    tap.pressed(at: 20)
    tap.interrupted()
    let withCommand = tap.released(at: 20.1)
    #expect(!withCommand)
    let again = tap.released(at: 20.2)
    #expect(!again)
}

@Test("A skipped folder skips everything inside it, and nothing beside it")
func skippedFolders() {
    let skips = PreviewSkips(folders: ["/Volumes/NAS"])
    #expect(skips.skips(path: "/Volumes/NAS", type: nil))
    #expect(skips.skips(path: "/Volumes/NAS/Photos/a.jpg", type: "public.jpeg"))
    #expect(!skips.skips(path: "/Volumes/NAS2/a.jpg", type: "public.jpeg"))
    let temp = PreviewSkips(folders: ["/var/folders/T"])
    #expect(temp.skips(path: "/private/var/folders/T/a.txt", type: nil))
}

@Test("A skipped type skips every type that conforms to it")
func skippedTypes() {
    let skips = PreviewSkips(types: ["public.image"])
    #expect(skips.skips(path: "/a.png", type: PreviewSkips.type(ofPath: "/a.png", isFolder: false)))
    #expect(!skips.skips(path: "/a.txt", type: PreviewSkips.type(ofPath: "/a.txt", isFolder: false)))
    #expect(!skips.skips(path: "/Makefile", type: PreviewSkips.type(ofPath: "/Makefile", isFolder: false)))
    #expect(PreviewSkips.type(ofPath: "/Users", isFolder: true) == "public.folder")
}
