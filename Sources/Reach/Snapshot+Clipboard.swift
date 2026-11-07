import AppKit
import ReachKit

extension Snapshot {
    /// S-026: sample clips in the store for the length of `body`, never what this Mac copied.
    static func withSampleClips(model: AppModel, _ body: (ClipboardHistory) async -> Void) async {
        let context = model.container.mainContext
        let clips = ClipboardHistory(pasteboard: .withUniqueName(), context: context)
        let sampleClips = [("Meeting notes\nShip the clipboard viewer on Friday.\nAsk Ada about the snippets.", "Notes", 3),
                           ("https://example.com/docs/clipboard", "Safari", 25),
                           ("/Applications/Safari.app\n/Applications/Mail.app", "Finder", 90),
                           ("let viewer = ClipboardViewer(history: clips)", "Xcode", 300)]
            .map { text, app, minutes in
                let item = ClipboardItem(kind: text.hasPrefix("/") ? .files : .text, text: text, sourceApp: app)
                item.copiedAt = Date.now.addingTimeInterval(TimeInterval(-minutes * 60))
                context.insert(item)
                return item
            }
        await body(clips)
        sampleClips.forEach(context.delete)
        try? context.save()
        ClipboardSettings.shared.reset()
    }

    /// The clipboard viewer on `history` (nil shows it empty), filtered by `filter`.
    static func clipboardViewer(_ history: ClipboardHistory?, filter: String? = nil) -> @MainActor (AppModel) async -> Void {
        { model in
            ClipboardSettings.shared.keep[.text] = true
            model.launcherModel.clipboard = history
            model.launcherModel.showClipboard()
            if let filter { model.launcherModel.viewer?.filter = filter }
            try? await Task.sleep(for: .seconds(0.5))
        }
    }
}
