import AppKit
import ReachKit

extension SelfTest {
    /// S-032: a theme picked in Settings applies to the real bar at once, and
    /// the preview sits on the desktop picture only while the toggle is on.
    /// Test runs draw a sample picture, never the person's own.
    static func checkThemes(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let themes = LauncherThemeStore.shared
        defer { themes.reset() }
        check("the standard theme is Reach, which follows the Mac",
              themes.theme == .standard && launcher.panel.appearance == nil)
        themes.themeID = "solid-dark"
        try? await Task.sleep(for: .milliseconds(50))
        check("picking Solid Dark makes the bar dark and solid at once",
              launcher.panel.appearance?.name == .darkAqua && themes.theme.surface == .solid,
              launcher.panel.appearance?.name.rawValue ?? "follows the Mac")
        themes.themeID = "reach-light"
        try? await Task.sleep(for: .milliseconds(50))
        check("and Reach Light makes it light glass", launcher.panel.appearance?.name == .aqua && themes.theme.surface == .glass)
        themes.themeID = "gone"
        try? await Task.sleep(for: .milliseconds(50))
        check("a theme that is gone falls back to Reach", themes.theme == .standard && launcher.panel.appearance == nil)
        themes.previewOnDesktop = true
        check("Show on Desktop Picture puts the preview on a picture", themes.previewPicture() != nil)
        themes.previewOnDesktop = false
        check("and off, on the plain background", themes.previewPicture() == nil)
    }

    /// S-033: own themes. A copy of a built-in theme is picked and can be
    /// changed; the built-in one cannot. Changes reach the bar at once.
    static func checkOwnThemes(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let themes = LauncherThemeStore.shared
        defer { themes.reset() }
        let builtIn = LauncherTheme.named("reach-dark")
        var changed = builtIn
        changed.cornerRadius = 4
        themes.update(changed)
        check("a built-in theme cannot be changed", LauncherTheme.named("reach-dark", in: themes.own).cornerRadius == 24)
        var own = themes.duplicate(builtIn)
        check("Duplicate makes an own copy and picks it",
              own.name == "Reach Dark Copy" && !own.isBuiltIn && themes.themeID == own.id && themes.own.count == 1)
        own.selectionColor = ThemeColor(red: 1, green: 0.85, blue: 0.2)
        own.fontName = "Avenir Next"
        own.cornerRadius = 99
        own.mode = .light
        themes.update(own)
        try? await Task.sleep(for: .milliseconds(50))
        let style = LauncherStyle(theme: themes.theme)
        check("a change to the own theme reaches the bar at once",
              launcher.panel.appearance?.name == .aqua && themes.theme.selectionColor == own.selectionColor,
              launcher.panel.appearance?.name.rawValue ?? "follows the Mac")
        check("sizes stay in range", themes.theme.cornerRadius == LauncherTheme.cornerRadii.upperBound)
        check("text on a light selection color is dark", style.onSelection == .black)
        check("own themes are saved", Store.settings.data(forKey: "appearance.ownThemes")?.isEmpty == false)
        themes.duplicate(themes.theme)
        check("a second copy gets its own name", themes.own.last?.name == "Reach Dark Copy Copy")
        let picked = themes.themeID
        let gone = themes.delete(picked)
        check("deleting the picked theme picks Reach", themes.themeID == LauncherTheme.standard.id && themes.own.count == 1)
        if let gone { themes.restore(gone.theme, at: gone.index, pick: gone.wasPicked) }
        check("Undo brings it back, picked", themes.themeID == picked && themes.own.count == 2)
        check("built-in themes have no Delete", themes.delete("reach") == nil)
    }
}
