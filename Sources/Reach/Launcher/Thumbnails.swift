import AppKit
import QuickLookThumbnailing
import ReachKit

/// Thumbnails for image, PDF and movie rows, made by Quick Look off the main thread (S-056).
/// Rows show the file icon until `images` has their path; nothing here ever waits on disk.
@Observable
final class Thumbnails {
    static let shared = Thumbnails()
    /// The largest icon a row shows; compact rows scale it down.
    static let side = LauncherLayout.iconSize
    /// Thumbnails kept in memory; the oldest go first.
    static let limit = 300

    /// Ready thumbnails by file path. Rows read this, so a new one redraws them.
    private(set) var images: [String: NSImage] = [:]
    @ObservationIgnored private var asked: Set<String> = []
    @ObservationIgnored private var order: [String] = []
    /// For the self-test: thumbnails made, and whether every one came back off the main thread.
    @ObservationIgnored private(set) var made = 0
    @ObservationIgnored private(set) var allOffMain = true

    /// The path whose thumbnail `result`'s row shows, or nil to keep the file icon.
    func path(for result: LaunchResult, settings: PreviewSettings = .shared) -> String? {
        guard case .file(let path) = result.icon, result.url?.isFileURL == true else { return nil }
        return ThumbnailRule.wants(path: path, isFolder: result.isFolder, enabled: settings.thumbnails, skips: settings.skips) ? path : nil
    }

    /// Asks Quick Look once per path. Cancelled when the row scrolls away, so it can ask again later.
    func load(_ path: String) async {
        guard images[path] == nil, asked.insert(path).inserted else { return }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let made = await Self.quickLook(URL(fileURLWithPath: path), side: Self.side, scale: scale)
        guard let made else {
            // Cancelled: ask again next time. Quick Look has none: keep the icon, don't ask again.
            if Task.isCancelled { asked.remove(path) }
            return
        }
        self.made += 1
        if !made.offMain { allOffMain = false }
        guard let image = made.image else { return }
        images[path] = NSImage(cgImage: image, size: NSSize(width: Self.side, height: Self.side))
        order.append(path)
        if order.count > Self.limit {
            let old = order.removeFirst()
            images[old] = nil
            asked.remove(old)
        }
    }

    /// Forgets every thumbnail, for the self-test.
    func reset() {
        images = [:]
        asked = []
        order = []
        made = 0
        allOffMain = true
    }

    private nonisolated struct Made: @unchecked Sendable {
        let image: CGImage?
        let offMain: Bool
    }

    /// The request, for the cancel handler. QLThumbnailGenerator is thread-safe.
    private nonisolated struct Job: @unchecked Sendable {
        let request: QLThumbnailGenerator.Request
        var generator: QLThumbnailGenerator { .shared }
    }

    /// Quick Look's thumbnail for `url`, or nil when the task was cancelled first.
    private nonisolated static func quickLook(_ url: URL, side: CGFloat, scale: CGFloat) async -> Made? {
        let job = Job(request: QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: side, height: side),
                                                            scale: scale, representationTypes: .thumbnail))
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (done: CheckedContinuation<Made?, Never>) in
                job.generator.generateBestRepresentation(for: job.request) { representation, _ in
                    done.resume(returning: Made(image: representation?.cgImage, offMain: !Thread.isMainThread))
                }
            }
        } onCancel: {
            job.generator.cancel(job.request)
        }
    }
}
