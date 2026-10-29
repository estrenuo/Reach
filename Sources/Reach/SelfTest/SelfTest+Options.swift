import AppKit
import ReachKit

extension SelfTest {
    /// S-034: Launcher Options. Fewer rows, the subtext and shortcut settings,
    /// and the screen the bar shows on. A fake source, so any Mac gives the same rows.
    static func checkLauncherOptions(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let options = LauncherOptionsStore.shared
        let realSources = lm.sources
        defer {
            options.reset()
            lm.sources = realSources
            lm.query = ""
        }
        check("nine rows and the mouse screen at first",
              options.visibleResults == 9 && options.subtext == .selected && !options.hidesShortcuts && options.screen == .mouse)
        lm.sources = [FakeSource(["Console", "Contacts", "ColorSync Utility", "Calculator", "Calendar", "Chess",
                                  "Clock", "Compass", "Camera", "Cards", "Capture"])]
        options.visibleResults = 3
        lm.query = "c"
        check("Visible results 3 shows three rows", lm.results.count == 3, "\(lm.results.count)")
        options.visibleResults = 20
        lm.query = "ca"
        lm.query = "c"
        check("and stays at nine at most", options.visibleResults == 20 && lm.results.count == 9
              && Store.settings.integer(forKey: "launcher.visibleResults") == 9, "\(lm.results.count)")
        options.screen = .main
        launcher.show()
        let primary = NSScreen.screens.first?.frame ?? .zero
        check("Main Screen puts the bar on the screen with the menu bar", primary.contains(launcher.panel.frame))
        launcher.hide()
        options.screen = .activeWindow
        check("Active Screen finds a screen, with or without a window in front", options.screenForBar() != nil)
    }
}
