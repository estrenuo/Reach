import AppKit
import ReachKit

/// Music commands (S-059): `next`, `play`, `volume 50` and the rest give one
/// row each; ↩ sends it to Music and hides the launcher. Next Track and the
/// others show the playing song as their subtitle.
final class MusicSource: ResultSource {
    static let icon = LaunchResult.Icon.file(MusicPlayer.app)
    let settings: MusicSettings
    /// Music.app, or a fake in test runs.
    var player: MusicPlayer = .live

    init(settings: MusicSettings = .shared) {
        self.settings = settings
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query else { return [] }
        let matches = MusicKeywords.matches(text, in: settings.keywords, defaultResults: settings.showsInDefaultResults)
        guard !matches.isEmpty else { return [] }
        let denied = player.access() == .denied
        return matches.map { match in
            Scored(result: row(match, denied: denied), score: match.score)
        }
    }

    private func row(_ match: MusicKeywords.Match, denied: Bool) -> LaunchResult {
        let command = match.command
        var row = LaunchResult(id: "music:\(command.rawValue)", title: command.title, subtitle: command.help,
                               icon: Self.icon, url: nil, kindLabel: "Music command")
        switch match.ask {
        case .needsVolume:
            row.title = "Type a volume from 0 to 100"
            row.subtitle = ""
            // Part of the keyword completes it, so ↩ leaves the cursor after `volume `.
            if match.score < 2000 {
                row.title = "\(command.title)…"
                row.subtitle = "Press ↩ to type a volume from 0 to 100"
                row.completes = settings[command].keyword + " "
            }
            return row
        case .badVolume:
            row.title = "Volume goes from 0 to 100"
            row.subtitle = ""
            return row
        case .run(let request):
            row.music = request
            row.isPinned = match.score >= 2000
            if case .setVolume(let level) = request {
                row.title = "Set Volume to \(level)"
                row.subtitle = "Set Music's volume to \(level)"
            } else if command.showsTrack, let track = player.nowPlaying() {
                row.subtitle = track.subtitle
            }
            if denied { row.subtitle = MusicPlayer.allowText }
            return row
        }
    }
}
