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
}
