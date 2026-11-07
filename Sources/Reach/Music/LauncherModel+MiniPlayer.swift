import AppKit
import ReachKit

extension KeyCombo {
    /// The mini player (S-060): ⌃⌘↩, as in Alfred.
    static let miniPlayer = KeyCombo(keyCode: 36, modifiers: control | command)
}

extension LauncherModel {
    /// True while the query is the mini player's keyword (S-060).
    var inMiniPlayer: Bool { miniPlayerPath != nil }

    var miniPlayerPath: MiniPlayerPath? {
        MiniPlayerPath.parse(query, keyword: MusicSettings.shared.miniPlayerKeyword)
    }

    /// The mini player's rows when the query is its keyword; nil otherwise, so
    /// the other sources answer. The list keeps its own order and has no fallbacks.
    func miniPlayerRows() -> [LaunchResult]? {
        guard let path = miniPlayerPath else {
            music.enters = [:]
            return nil
        }
        music.enters = [:]
        let reader = music.library
        let settings = MusicSettings.shared
        guard let catalog = reader.catalog(settings.include) else {
            guard reader.state == .denied else { return [MiniPlayerRows.hint("Reading your music library…")] }
            var row = MiniPlayerRows.hint(MusicLibraryReader.allowText)
            row.id = "mini:access"
            row.url = MusicLibraryReader.privacySettings
            return [row]
        }
        let builder = MiniPlayerRows(path: path, library: catalog, settings: settings, artwork: reader.artwork)
        let rows = builder.rows()
        music.enters = builder.enters
        return rows
    }

    /// The mini player hotkey: shows the launcher on the mini player's top list,
    /// or hides it when the mini player shows.
    func openMiniPlayer() {
        actions = nil
        viewer = nil
        rewriteQuery(MusicSettings.shared.miniPlayerKeyword + " ")
    }

    /// → (and Tab) in the mini player: into the selected album, artist or playlist.
    func enterMiniPlayer() -> Bool {
        guard inMiniPlayer, let id = selectedResult?.id, let target = music.enters[id] else { return false }
        rewriteQuery(target)
        return true
    }

    /// ← in the mini player: clears the typed text, else goes back one list.
    func backMiniPlayer() -> Bool {
        guard let up = miniPlayerPath?.back() else { return false }
        rewriteQuery(up)
        return true
    }

    /// Shows the list once the library is read, and the artwork as it arrives.
    func followMusicLibrary() {
        music.library.onChange = { [weak self] in
            guard let self, self.inMiniPlayer else { return }
            self.refresh()
        }
    }
}
