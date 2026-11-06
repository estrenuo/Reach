import AppKit
import ReachKit
import SwiftUI

extension Snapshot {
    /// S-059: the music command rows with a fake Music (a sample song, never
    /// this Mac's), the row without Automation, and Settings > Music.
    static func captureMusic(model: AppModel, dir: String, openSettings: OpenSettingsAction) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let player = lm.music.player
        final class Flag { var denied = false }
        let flag = Flag()
        defer { lm.music.player = player }
        lm.music.player = SelfTest.fakeMusic(access: { flag.denied ? .denied : .allowed })
        let states = [("music-next", "next", false), ("music-volume", "volume 30", false), ("music-volume-hint", "volume 150", false),
                      ("music-partial", "pre", false), ("music-denied", "play", true)]
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            for (name, query, noAccess) in states {
                flag.denied = noAccess
                launcher.show()
                lm.query = query
                try? await Task.sleep(for: .seconds(1))
                capture(to: "\(dir)/launcher-\(name)-\(mode).png", window: launcher.panel)
                launcher.hide()
            }
        }
        flag.denied = false
        let main = NSApp.windows.first { $0.canBecomeMain && !$0.isSheet }
        openSettings()
        model.settingsTab = .music
        try? await Task.sleep(for: .seconds(1))
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            try? await Task.sleep(for: .seconds(0.8))
            let settings = NSApp.windows.first { $0.isVisible && $0 !== main && !$0.isSheet && $0.styleMask.contains(.titled) }
            capture(to: "\(dir)/settings-music-\(mode).png", window: settings)
        }
    }
}
