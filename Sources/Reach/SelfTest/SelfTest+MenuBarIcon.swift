import AppKit
import ReachKit

extension SelfTest {
    /// S-035: the menu bar icon can be hidden, and "settings" in the bar opens
    /// Reach Settings either way. A recorder stands in for opening Settings.
    static func checkMenuBarIcon(model: AppModel) async {
        let lm = model.launcherModel
        let options = LauncherOptionsStore.shared
        var opened = 0
        let open = lm.openSettings
        lm.openSettings = { opened += 1 }
        defer {
            lm.openSettings = open
            options.reset()
            lm.query = ""
        }
        let icon = { model.menuBarIcon?.isVisible == true }
        check("the menu bar icon shows at first", options.showsMenuBarIcon && icon())
        options.showsMenuBarIcon = false
        try? await Task.sleep(for: .milliseconds(100))
        check("Show menu bar icon off takes the icon away", !icon())
        check("and stays off", Store.settings.object(forKey: "launcher.showsMenuBarIcon") as? Bool == false)
        for text in ["settings", "sett", "preferences"] {
            lm.query = text
            check("“\(text)” puts Reach Settings first", lm.results.first(where: \.isOpenable)?.id == "reach:settings",
                  lm.results.first?.title ?? "nothing")
        }
        lm.query = "settings"
        if let index = lm.results.firstIndex(where: { $0.id == "reach:settings" }) { lm.open(at: index) }
        check("Return on it opens Settings", opened == 1)
        options.showsMenuBarIcon = true
        try? await Task.sleep(for: .milliseconds(100))
        check("on again, the icon is back", icon())
    }
}
