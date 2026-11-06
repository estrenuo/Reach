import AppKit
import ReachKit

extension SelfTest {
    /// S-056: image rows show a Quick Look thumbnail, made off the main thread;
    /// until it arrives, and for files without one, the row keeps the file icon.
    /// Moving through 30 image rows never makes the launcher wait.
    static func checkThumbnails(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let thumbnails = Thumbnails.shared
        let settings = PreviewSettings.shared
        let fm = FileManager.default
        let root = NSTemporaryDirectory() + "reach-thumbnails/"
        try? fm.removeItem(atPath: root)
        try? fm.createDirectory(atPath: root, withIntermediateDirectories: true)
        let names = (1...30).map { String(format: "photo %02d.png", $0) }
        for (index, name) in names.enumerated() {
            fm.createFile(atPath: root + name, contents: samplePNG(hue: Double(index) / 30))
        }
        fm.createFile(atPath: root + "notes.txt", contents: Data("No thumbnail".utf8))
        defer {
            try? fm.removeItem(atPath: root)
            settings.thumbnails = true
            settings.skips = PreviewSkips()
            thumbnails.reset()
            launcher.hide()
        }
        func row(_ name: String) -> LaunchResult? { lm.results.first { $0.title == name } }
        func waitFor(_ ready: () -> Bool) async {
            for _ in 0..<40 where !ready() { try? await Task.sleep(for: .milliseconds(100)) }
        }

        check("the setting is on by default", settings.thumbnails)
        thumbnails.reset()
        launcher.show()
        try? await Task.sleep(for: .milliseconds(300))
        lm.query = root
        for _ in 0..<50 where row(names[0]) == nil { try? await Task.sleep(for: .milliseconds(10)) }
        guard let photo = row(names[0]), let notes = row("notes.txt") else {
            check("the test folder lists its files", false, lm.results.map(\.title).joined(separator: ", "))
            return
        }
        let photoPath = thumbnails.path(for: photo)
        check("an image row asks for a thumbnail", photoPath != nil)
        check("until it arrives, the row keeps the file icon",
              photoPath.map { thumbnails.images[$0] == nil } ?? false && photo.icon == .file(photo.url?.path ?? ""))
        await waitFor { photoPath.map { thumbnails.images[$0] != nil } ?? false }
        check("Quick Look makes the thumbnail", photoPath.map { thumbnails.images[$0] != nil } ?? false,
              "\(thumbnails.made) made")
        check("off the main thread", thumbnails.made > 0 && thumbnails.allOffMain)
        check("a text file keeps its icon", thumbnails.path(for: notes) == nil)

        // Move through every row like a held ↓ while Quick Look works, and watch the main thread.
        thumbnails.reset()
        lm.query = ""
        try? await Task.sleep(for: .milliseconds(200))
        lm.query = root
        try? await Task.sleep(for: .milliseconds(50))
        let gauge = MainThreadGauge()
        var slowestMove: Duration = .zero
        let heartbeat = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(5))
                gauge.beat()
            }
        }
        for _ in 0..<30 {
            let start = ContinuousClock.now
            lm.move(1)
            slowestMove = max(slowestMove, ContinuousClock.now - start)
            try? await Task.sleep(for: .milliseconds(33))
        }
        heartbeat.cancel()
        await heartbeat.value
        let longest = gauge.longest
        check("moving through 30 rows never waits on a thumbnail",
              longest < .milliseconds(100) && slowestMove < .milliseconds(20),
              "longest main-thread gap \(longest), slowest move \(slowestMove)")
        await waitFor { thumbnails.images.count >= 12 }
        check("the rows scrolled past get their thumbnails too", thumbnails.images.count >= 12, "\(thumbnails.images.count) thumbnails")

        settings.skips = PreviewSkips(types: ["public.png"])
        check("a skipped file type keeps its icon", thumbnails.path(for: photo) == nil)
        settings.skips = PreviewSkips(folders: [URL(fileURLWithPath: root).resolvingSymlinksInPath().path])
        check("so does a file in a skipped folder", thumbnails.path(for: photo) == nil)
        settings.skips = PreviewSkips()
        settings.thumbnails = false
        check("with the setting off, every row keeps its icon", thumbnails.path(for: photo) == nil)
    }

    /// The longest time the main thread went without a heartbeat.
    final class MainThreadGauge {
        private(set) var longest: Duration = .zero
        private var last = ContinuousClock.now
        func beat() {
            let now = ContinuousClock.now
            longest = max(longest, now - last)
            last = now
        }
    }

    /// A small picture in one colour with a darker circle, so Quick Look has a real picture to shrink.
    static func samplePNG(hue: Double, side: Int = 256, type: NSBitmapImageRep.FileType = .png) -> Data {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                                            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return Data() }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor(hue: hue, saturation: 0.6, brightness: 0.9, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()
        NSColor(hue: hue, saturation: 0.8, brightness: 0.5, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: side / 4, y: side / 4, width: side / 2, height: side / 2)).fill()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: type, properties: [:]) ?? Data()
    }
}
