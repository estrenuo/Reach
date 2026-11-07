import ReachKit

extension LauncherModel {
    /// ↩ on a music command (S-059): sends it to Music and hides the launcher.
    /// Without Automation the row says how to allow it, and ↩ opens that pane.
    func runMusic(_ request: MusicRequest, result: LaunchResult) {
        let player = music.player
        if player.access() == .denied {
            if let url = MusicPlayer.automationSettings { _ = opener(url) }
            onHide()
            return
        }
        switch player.send(request) {
        case .sent:
            if inMiniPlayer {
                if MusicSettings.shared.hidesAfterChoosing { onHide() }
                return
            }
            onOpened(query, result)
            onHide()
        case .denied:
            showError(MusicPlayer.allowText, on: result.id)
        case .failed:
            showError("Unable to reach Music.", on: result.id)
        }
    }
}
