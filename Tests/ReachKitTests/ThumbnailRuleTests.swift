import Testing
@testable import ReachKit

private func wants(_ path: String, folder: Bool = false, on: Bool = true, _ skips: PreviewSkips = PreviewSkips()) -> Bool {
    ThumbnailRule.wants(path: path, isFolder: folder, enabled: on, skips: skips)
}

@Test("Images, PDFs and movies get a thumbnail")
func thumbnailKinds() {
    #expect(wants("/Users/a/Holiday photo.jpg"))
    #expect(wants("/Users/a/Screen.PNG"))
    #expect(wants("/Users/a/Q3 report.pdf"))
    #expect(wants("/Users/a/Clip.mov"))
    #expect(wants("/Users/a/Clip.mp4"))
}

@Test("Folders, apps, documents and files without an extension keep their icon")
func thumbnailOthers() {
    #expect(!wants("/Users/a/Photos.jpg", folder: true))
    #expect(!wants("/Applications/Safari.app"))
    #expect(!wants("/Users/a/notes.txt"))
    #expect(!wants("/Users/a/Budget.numbers"))
    #expect(!wants("/Users/a/README"))
}

@Test("A skipped file type gets no thumbnail, also for a type it covers")
func thumbnailSkippedType() {
    #expect(!wants("/Users/a/Screen.png", PreviewSkips(types: ["public.png"])))
    #expect(!wants("/Users/a/Screen.png", PreviewSkips(types: ["public.image"])))
    #expect(wants("/Users/a/report.pdf", PreviewSkips(types: ["public.image"])))
}

@Test("Nothing in a skipped folder gets a thumbnail, also through /private")
func thumbnailSkippedFolder() {
    let skips = PreviewSkips(folders: ["/Volumes/NAS", "/private/tmp/shots"])
    #expect(!wants("/Volumes/NAS/Photos/beach.jpg", skips))
    #expect(!wants("/tmp/shots/a.png", skips))
    #expect(wants("/Volumes/NASA/beach.jpg", skips))
}

@Test("With the setting off, nothing gets a thumbnail")
func thumbnailOff() {
    #expect(!wants("/Users/a/Holiday photo.jpg", on: false))
}
