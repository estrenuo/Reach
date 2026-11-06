import AppKit
import ReachKit

extension SelfTest {
    /// A fake Music.app: records what Reach sends and plays one sample song.
    /// The self-test and snapshots never send a real Apple Event.
    static func fakeMusic(sent: @escaping @MainActor (MusicRequest) -> Void = { _ in },
                          outcome: @escaping @MainActor () -> MusicOutcome = { .sent },
                          access: @escaping @MainActor () -> MusicAccess = { .allowed }) -> MusicPlayer {
        MusicPlayer(send: { sent($0); return outcome() },
                    nowPlaying: { MusicTrack(name: "So What", artist: "Miles Davis") },
                    access: access)
    }

    /// S-059: music keywords send one command each to (fake) Music, `volume`
    /// takes 0 to 100, keywords turn off and rename, and without Automation
    /// the row says how to allow it.
    static func checkMusic(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let source = lm.music
        let settings = MusicSettings.shared
        check("test runs start with a silent player: no track, no access check",
              source.player.nowPlaying() == nil && source.player.access() == .unknown)
        var sent: [MusicRequest] = []
        var opened: [URL] = []
        final class Answers { var outcome = MusicOutcome.sent; var access = MusicAccess.allowed }
        let answers = Answers()
        let (player, opener) = (source.player, lm.opener)
        source.player = fakeMusic(sent: { sent.append($0) }, outcome: { answers.outcome }, access: { answers.access })
        lm.opener = { opened.append($0); return true }
        defer {
            settings.reset()
            (source.player, lm.opener) = (player, opener)
        }

        launcher.show()
        lm.query = "next"
        let next = lm.selectedResult
        check("next shows Next Track with the playing song as its subtitle",
              next?.title == "Next Track" && next?.subtitle == "So What — Miles Davis",
              "\(next?.title ?? "nil") / \(next?.subtitle ?? "")")
        lm.openSelected()
        check("↩ sends next track to Music and hides the launcher", sent == [.command(.next)] && !launcher.isVisible)

        for command in MusicCommand.allCases where !command.takesVolume {
            await showAgain(launcher)
            sent = []
            lm.query = command.defaultKeyword
            lm.openSelected()
            check("“\(command.defaultKeyword)” sends \(command.title)", sent == [.command(command)], "\(sent)")
        }

        await showAgain(launcher)
        sent = []
        lm.query = "volume 30"
        check("volume 30 shows Set Volume to 30", lm.selectedResult?.title == "Set Volume to 30")
        lm.openSelected()
        check("↩ sets Music's volume to 30", sent == [.setVolume(30)])
        await showAgain(launcher)
        lm.query = "volume"
        check("volume alone asks for a number", lm.results.first?.title == "Type a volume from 0 to 100"
              && lm.results.first?.isOpenable == false)
        lm.query = "volume 150"
        check("volume 150 says the range", lm.results.first?.title == "Volume goes from 0 to 100"
              && lm.results.first?.isOpenable == false)
        sent = []
        lm.openSelected()
        check("↩ on the hint sends nothing", sent.isEmpty)

        settings[.next].isOn = false
        lm.query = "next"
        check("a keyword turned off finds no music command", !lm.results.contains { $0.music != nil })
        settings[.next] = MusicKeyword(command: .next, keyword: "skip")
        lm.query = "skip"
        check("a renamed keyword finds its command", lm.selectedResult?.music == .command(.next))
        settings.showsInDefaultResults = false
        lm.query = "previ"
        check("with Show in default results off, part of a keyword finds nothing", !lm.results.contains { $0.music != nil })
        settings.showsInDefaultResults = true
        lm.query = "previ"
        check("with it on, part of a keyword finds the command", lm.results.contains { $0.music == .command(.previous) })

        answers.access = .denied
        lm.query = "play"
        check("without Automation the row says how to allow it", lm.selectedResult?.subtitle == MusicPlayer.allowText)
        sent = []
        lm.openSelected()
        check("↩ then opens Privacy & Security > Automation and sends nothing",
              sent.isEmpty && opened.last == MusicPlayer.automationSettings && !launcher.isVisible)

        await showAgain(launcher)
        answers.access = .unknown
        answers.outcome = .denied
        lm.query = "play"
        lm.openSelected()
        check("when macOS refuses on ↩, the row says how to allow it and the launcher stays",
              lm.errors["music:playPause"] == MusicPlayer.allowText && launcher.isVisible)
        launcher.hide()
    }
}
