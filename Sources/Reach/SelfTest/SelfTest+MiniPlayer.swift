import AppKit
import ReachKit

extension SelfTest {
    /// A made-up library with drawn artwork, the same on every Mac; the
    /// self-test and snapshots never read the person's own music.
    static let sampleMusic = MusicLibrary(
        songs: [
            MusicSong(id: "00000000000000A1", title: "So What", artist: "Miles Davis", album: "Kind of Blue", albumID: "KOB", number: 1),
            MusicSong(id: "00000000000000A2", title: "Freddie Freeloader", artist: "Miles Davis", album: "Kind of Blue", albumID: "KOB", number: 2),
            MusicSong(id: "00000000000000A3", title: "Blue in Green", artist: "Miles Davis", album: "Kind of Blue", albumID: "KOB", number: 3),
            MusicSong(id: "00000000000000A4", title: "All Blues", artist: "Miles Davis", album: "Kind of Blue", albumID: "KOB", number: 4),
            MusicSong(id: "00000000000000A5", title: "Flamenco Sketches", artist: "Miles Davis", album: "Kind of Blue", albumID: "KOB", number: 5),
            MusicSong(id: "00000000000000B1", title: "Take Five", artist: "Dave Brubeck Quartet", album: "Time Out", albumID: "TO", number: 1),
            MusicSong(id: "00000000000000B2", title: "Blue Rondo à la Turk", artist: "Dave Brubeck Quartet", album: "Time Out", albumID: "TO", number: 2),
            MusicSong(id: "00000000000000C1", title: "Moanin'", artist: "Art Blakey", album: "Moanin'", albumID: "MO", number: 1),
            MusicSong(id: "00000000000000D1", title: "Episode 12", artist: "Studio Radio", album: "The Show", albumID: "SHOW", kind: .podcast),
        ],
        playlists: [MusicPlaylist(id: "00000000000000E1", name: "Evening", songIDs: ["00000000000000A3", "00000000000000B1"])])

    /// Drawn album covers in /tmp, one color per album.
    static func sampleArtwork() -> @MainActor (String) -> String? {
        let folder = "/tmp/Reach-sample-artwork"
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let colors: [String: (NSColor, NSColor)] = ["KOB": (.systemBlue, .systemIndigo), "TO": (.systemOrange, .systemRed),
                                                    "MO": (.systemTeal, .systemGreen)]
        for (id, pair) in colors {
            let path = "\(folder)/\(id).png"
            guard !FileManager.default.fileExists(atPath: path) else { continue }
            let image = NSImage(size: NSSize(width: 128, height: 128), flipped: false) { rect in
                NSGradient(starting: pair.0, ending: pair.1)?.draw(in: rect, angle: 45)
                let note = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)?
                    .withSymbolConfiguration(.init(pointSize: 56, weight: .semibold))
                note?.draw(in: rect.insetBy(dx: 32, dy: 32), from: .zero, operation: .destinationOut, fraction: 0.5)
                return true
            }
            if let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
            }
        }
        let ids = Set(colors.keys)
        return { id in ids.contains(id) ? "\(folder)/\(id).png" : nil }
    }

    /// S-060: `music` and the hotkey show the mini player; → and ↩ go into a
    /// list, ← goes back, typing filters; ↩ plays through the (fake) player.
    static func checkMiniPlayer(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let reader = lm.music.library
        let settings = MusicSettings.shared
        let hotkeys = HotkeyCenter.shared
        check("test runs never register the mini player hotkey", !hotkeys.miniPlayerRegistered)
        check("test runs never read the person's music library", !reader.loaderIsLive)
        final class Box { var sent: [MusicRequest] = []; var opened: [URL] = []; var loads = 0; var library: MusicLibrary? = SelfTest.sampleMusic }
        let box = Box()
        let (player, opener, loader, artwork) = (lm.music.player, lm.opener, reader.loader, reader.artwork)
        lm.music.player = fakeMusic(sent: { box.sent.append($0) })
        lm.opener = { box.opened.append($0); return true }
        reader.forget()
        reader.loader = { done in box.loads += 1; done(box.library) }
        reader.artwork = sampleArtwork()
        defer {
            settings.reset()
            (lm.music.player, lm.opener, reader.loader, reader.artwork) = (player, opener, loader, artwork)
            reader.forget()
        }

        launcher.show()
        lm.query = "music"
        check("music shows Albums, Artists, Playlists, Random Album and Open Music",
              lm.results.map(\.title) == ["Albums", "Artists", "Playlists", "Random Album", "Open Music"],
              lm.results.map(\.title).joined(separator: ", "))
        check("the library is read the first time", box.loads == 1)
        check("Albums says how many", lm.results.first?.subtitle == "3 albums", lm.results.first?.subtitle ?? "")
        lm.query = "music alb"
        check("typing filters the top list", lm.results.first?.title == "Albums")
        lm.query = "music "
        check("the library is read once, not on every query", box.loads == 1)
        lm.select(0)
        check("→ goes into Albums", lm.enter() && lm.query == "music Albums › ")
        check("albums show A to Z with their artist and count",
              lm.results.map(\.title) == ["Kind of Blue", "Moanin'", "Time Out"]
              && lm.results.first?.subtitle == "Miles Davis · 5 songs", lm.results.map(\.title).joined(separator: ", "))
        check("an album row shows its artwork", lm.results.first?.icon == .image("/tmp/Reach-sample-artwork/KOB.png"))
        lm.query = "music Albums › time"
        check("typing filters the albums", lm.results.first?.title == "Time Out")
        lm.query = "music Albums › zzqxv"
        check("no match says so", lm.results.first?.title == "No albums match “zzqxv”" && lm.results.first?.isOpenable == false)
        lm.query = "music Albums › "
        lm.select(0)
        _ = lm.enter()
        check("→ on an album shows its songs in order with track numbers",
              lm.query == "music Albums › Kind of Blue — Miles Davis › "
              && lm.results.prefix(2).map(\.title) == ["So What", "Freddie Freeloader"] && lm.results.first?.badge == "1",
              lm.query)
        check("songs show the album's artwork", lm.results.first?.icon == .image("/tmp/Reach-sample-artwork/KOB.png"))
        check("← goes back to the albums", lm.back() && lm.query == "music Albums › ")
        lm.query = "music Albums › kin"
        check("← first clears the typed text", lm.back() && lm.query == "music Albums › ")
        check("← again goes to the top", lm.back() && lm.query == "music ")
        check("← at the top does nothing", !lm.back())

        lm.query = "music Albums › "
        lm.select(0)
        lm.openSelected()
        check("↩ on an album plays its songs and hides the launcher (Hide after choosing)",
              box.sent.last == .playSongs(sampleMusic.songs.prefix(5).map(\.id)) && !launcher.isVisible, "\(box.sent)")
        await showAgain(launcher)
        settings.hidesAfterChoosing = false
        lm.query = "music Playlists › "
        check("Playlists lists the playlists", lm.results.map(\.title) == ["Evening"])
        lm.openSelected()
        check("↩ on a playlist plays it; with Hide after choosing off the launcher stays",
              box.sent.last == .playPlaylist("00000000000000E1") && launcher.isVisible)
        lm.query = "music Artists › "
        lm.select(0)
        check("artists list A to Z", lm.results.map(\.title) == ["Art Blakey", "Dave Brubeck Quartet", "Miles Davis"])
        _ = lm.enter()
        check("→ on an artist shows their albums", lm.results.map(\.title) == ["Moanin'"])
        lm.query = "music Albums › Kind of Blue — Miles Davis › "
        lm.select(2)
        lm.openSelected()
        check("↩ on a song plays it", box.sent.last == .playSong("00000000000000A3"))

        settings.randomMinimum = 2
        lm.query = "music random"
        var pick = Set<[String]>()
        for _ in 0..<20 {
            lm.refresh()
            if case .playSongs(let ids)? = lm.selectedResult?.music { pick.insert(ids) }
        }
        check("Random Album skips albums with fewer songs than the setting",
              !pick.isEmpty && pick.allSatisfy { $0.count >= 2 } && !pick.contains(["00000000000000C1"]), "\(pick)")
        settings.randomMinimum = 6
        lm.refresh()
        check("with no album long enough, Random Album says so",
              lm.results.first?.subtitle == "No album has 6 songs or more" && lm.results.first?.isOpenable == false)

        settings.include.podcasts = true
        lm.query = "music Albums › "
        check("podcasts show only when Include Podcasts is on", lm.results.contains { $0.title == "The Show" })
        settings.include.podcasts = false
        lm.refresh()
        check("…and go when it is off", !lm.results.contains { $0.title == "The Show" })

        reader.libraryChanged()
        check("the library is read again when Music says it changed", box.loads == 2)

        reader.forget()
        box.library = nil
        lm.query = "music Albums › x"
        lm.query = "music "
        check("without access to the library the row says how to allow it",
              lm.results.first?.title == MusicLibraryReader.allowText)
        lm.openSelected()
        check("↩ then opens Privacy & Security > Media & Apple Music", box.opened.last == MusicLibraryReader.privacySettings)

        reader.forget()
        box.library = sampleMusic
        launcher.hide()
        try? await Task.sleep(for: .milliseconds(150))
        hotkeys.onMiniPlayer()
        try? await Task.sleep(for: .milliseconds(300))
        check("the mini player hotkey shows the launcher on the mini player",
              launcher.isVisible && lm.query == "music " && lm.results.first?.title == "Albums")
        hotkeys.onMiniPlayer()
        check("pressing it again hides the launcher", !launcher.isVisible)
        lm.query = ""
    }
}
