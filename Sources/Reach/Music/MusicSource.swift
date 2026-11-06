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
    /// The Music library for the mini player (S-060).
    let library = MusicLibraryReader()
    /// Where → goes from a mini player row, by result id.
    var enters: [String: String] = [:]

    init(settings: MusicSettings = .shared) {
        self.settings = settings
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .normal(let text) = query else { return [] }
        let matches = MusicKeywords.matches(text, in: settings.keywords, defaultResults: settings.showsInDefaultResults)
        guard !matches.isEmpty else { return [] }
        let denied = player.access() == .denied
        // A keyword a system command also uses (`mute`) keeps the system command
        // first, as before; the music command shows right under it.
        let system = Set(SystemSettings.shared.commands.filter(\.isOn).map { $0.keyword.lowercased() })
        return matches.map { match in
            var row = row(match, denied: denied)
            let shared = match.score >= 2000 && system.contains(settings[match.command].keyword.lowercased())
            if shared { row.isPinned = false }
            return Scored(result: row, score: shared ? Self.sharedScore : match.score)
        }
    }

    /// Below an exact system command, above most other matches.
    static let sharedScore = 900

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
