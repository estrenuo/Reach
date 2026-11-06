import AppKit
import ReachKit

extension Snapshot {
    /// S-060: the mini player's top list, the albums, and inside an album with
    /// artwork, from a sample library (never this Mac's).
    static func captureMiniPlayer(model: AppModel, dir: String) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let reader = lm.music.library
        let (loader, artwork) = (reader.loader, reader.artwork)
        reader.forget()
        reader.loader = { $0(SelfTest.sampleMusic) }
        reader.artwork = SelfTest.sampleArtwork()
        defer {
            (reader.loader, reader.artwork) = (loader, artwork)
            reader.forget()
        }
        let states = [("mini-player", "music "), ("mini-player-albums", "music Albums › "),
                      ("mini-player-album", "music Albums › Kind of Blue — Miles Davis › ")]
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            for (name, query) in states {
                launcher.show()
                lm.query = query
                try? await Task.sleep(for: .seconds(1))
                capture(to: "\(dir)/launcher-\(name)-\(mode).png", window: launcher.panel)
                launcher.hide()
            }
        }
    }
}
