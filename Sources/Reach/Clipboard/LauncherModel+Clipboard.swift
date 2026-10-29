import ReachKit

/// The launcher's side of the clipboard viewer (S-026).
extension LauncherModel {
    /// ⌃⌥⌘C or ↩ on the Clipboard History row: the viewer, newest clip selected.
    func showClipboard(fromLauncher: Bool = false) {
        viewer = ClipboardViewer(history: clipboard, fromLauncher: fromLauncher)
        onResultsChange()
    }

    /// ↩ in the viewer: pastes the clip into the app in front, or only copies
    /// it when Paste on Return is off. The clip moves to the top.
    func useClip(at index: Int) {
        guard let viewer, viewer.entries.indices.contains(index) else { return }
        viewer.select(index)
        switch viewer.entries[index].kind {
        case .snippets:
            onHide()
            openSnippets()
        case .turnOn:
            onHide()
            AppModel.shared.settingsTab = .clipboard
            openSettings()
        case .clip(let item):
            clipboard?.use(item)
            onHide()
            if viewer.settings.pastesOnReturn { paster() }
        case .noMatch:
            return
        }
    }

    /// ⌘C in the viewer: copies the selected clip without pasting. False when no clip is selected.
    func copySelectedClip() -> Bool {
        guard let item = viewer?.selected?.clip else { return false }
        clipboard?.use(item)
        onHide()
        return true
    }

    /// Esc in the viewer: clears the filter, then goes back to the results or hides.
    func cancelClipboard() {
        guard let viewer else { return }
        if !viewer.filter.isEmpty {
            viewer.filter = ""
            return
        }
        guard viewer.fromLauncher else { return onHide() }
        self.viewer = nil
        onResultsChange()
    }
}

/// The Clipboard History row (S-026): typing "clipboard", or part of it, offers the viewer.
final class ClipboardSource: ResultSource {
    static let title = "Clipboard History"

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query, text.count >= 3,
              let score = Matcher.score(query: text, title: Self.title) else { return [] }
        let row = LaunchResult(id: "clipboard:viewer", title: Self.title,
                               subtitle: "Browse and paste what you copied (\(KeyCombo.clipboard.display(key: "C")))",
                               icon: .symbol("list.clipboard"), url: nil, kindLabel: "Clipboard", opensClipboard: true)
        return [Scored(result: row, score: score)]
    }
}
