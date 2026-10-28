import AppKit
import Quartz

/// The system Quick Look panel for the selected result (S-012). The launcher
/// stays the key window, so ↑ and ↓ keep working and Quick Look follows them.
/// The launcher panel hands this object to Quick Look as its data source.
final class QuickLook: NSObject, @preconcurrency QLPreviewPanelDataSource {
    static let shared = QuickLook()
    /// The file on show, or nil when Quick Look is closed.
    private(set) var url: URL?

    var isOpen: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
    }

    /// The file Quick Look shows for a result: nil for web searches and hints,
    /// for skipped types and folders, and when Quick Look is off in Settings.
    static func file(for result: LaunchResult?) -> URL? {
        let settings = PreviewSettings.shared
        guard settings.quickLook, let result, let url = result.url, url.isFileURL,
              !settings.skips(url, isFolder: result.isFolder) else { return nil }
        return url
    }

    /// ⇧ or ⌘Y: closes Quick Look, or opens it on the result. False when there is nothing to show.
    func toggle(_ result: LaunchResult?) -> Bool {
        if isOpen {
            close()
            return true
        }
        guard let file = Self.file(for: result), let panel = QLPreviewPanel.shared() else { return false }
        url = file
        // Above the launcher, which floats at the status bar level.
        panel.level = NSWindow.Level(NSWindow.Level.statusBar.rawValue + 1)
        // Shown, not made key: the launcher keeps the keyboard.
        panel.orderFront(nil)
        panel.reloadData()
        return true
    }

    /// The selection moved: show the new result, or close when it has no file.
    func follow(_ result: LaunchResult?) {
        guard isOpen else { return }
        guard let file = Self.file(for: result) else { return close() }
        guard file != url else { return }
        url = file
        QLPreviewPanel.shared().reloadData()
    }

    func close() {
        url = nil
        // Also while it is still opening, when isVisible is not yet true.
        guard QLPreviewPanel.sharedPreviewPanelExists() else { return }
        QLPreviewPanel.shared().orderOut(nil)
        // During its opening animation Quick Look ignores orderOut. Try again
        // until the animation is over, unless it was opened again meanwhile.
        retryClose(times: 3)
    }

    private func retryClose(times: Int) {
        guard times > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.url == nil, self.isOpen else { return }
            QLPreviewPanel.shared().orderOut(nil)
            self.retryClose(times: times - 1)
        }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        url == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        url as NSURL?
    }
}
