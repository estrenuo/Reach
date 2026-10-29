import AppKit
import ReachKit

/// Launcher Options (S-034): rows, subtext, shortcuts and the screen, saved in `Store.settings`.
@Observable
final class LauncherOptionsStore {
    static let shared = LauncherOptionsStore()

    var visibleResults: Int {
        didSet { Store.settings.set(LauncherOptions.clampedVisible(visibleResults), forKey: "launcher.visibleResults") }
    }
    var subtext: LauncherOptions.Subtext { didSet { Store.settings.set(subtext.rawValue, forKey: "launcher.subtext") } }
    var hidesShortcuts: Bool { didSet { Store.settings.set(hidesShortcuts, forKey: "launcher.hidesShortcuts") } }
    var screen: LauncherOptions.Screen { didSet { Store.settings.set(screen.rawValue, forKey: "launcher.screen") } }
    var showsMenuBarIcon: Bool { didSet { Store.settings.set(showsMenuBarIcon, forKey: "launcher.showsMenuBarIcon") } }
    /// The Launcher Options sheet is open. Not saved.
    var isEditing = false

    private init() {
        let settings = Store.settings
        visibleResults = LauncherOptions.clampedVisible(
            settings.object(forKey: "launcher.visibleResults") as? Int ?? LauncherOptions.standardVisibleResults)
        subtext = settings.string(forKey: "launcher.subtext").flatMap(LauncherOptions.Subtext.init) ?? .selected
        hidesShortcuts = settings.bool(forKey: "launcher.hidesShortcuts")
        screen = settings.string(forKey: "launcher.screen").flatMap(LauncherOptions.Screen.init) ?? .mouse
        showsMenuBarIcon = settings.object(forKey: "launcher.showsMenuBarIcon") as? Bool ?? true
    }

    func reset() {
        visibleResults = LauncherOptions.standardVisibleResults
        subtext = .selected
        hidesShortcuts = false
        screen = .mouse
        showsMenuBarIcon = true
        isEditing = false
    }

    /// The screen to show the bar on, by the chosen rule.
    func screenForBar() -> NSScreen? {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return nil }
        // Window bounds come in top-left coordinates of the menu bar screen; turn the screens and the mouse into those.
        func flipped(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX, y: primary.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
        }
        let mouse = NSEvent.mouseLocation
        let index = LauncherOptions.screen(screen, screens: screens.map { flipped($0.frame) },
                                           mouse: CGPoint(x: mouse.x, y: primary.frame.maxY - mouse.y),
                                           activeWindow: screen == .activeWindow ? Self.frontWindowBounds() : nil)
        return index.map { screens[$0] }
    }

    /// The front app's top window. Bounds need no Screen Recording permission; names would.
    private static func frontWindowBounds() -> CGRect? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        let window = windows.first {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && ($0[kCGWindowLayer as String] as? Int) == 0
        }
        guard let bounds = window?[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: bounds as CFDictionary)
    }
}
