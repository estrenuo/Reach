import CoreGraphics

/// How the bar behaves and where it shows (S-034), set in Launcher Options.
public enum LauncherOptions {
    /// How many result rows the bar shows: ⌘1 to ⌘N always fit.
    public static let visibleResults: ClosedRange<Int> = 3...9
    public static let standardVisibleResults = 9

    public static func clampedVisible(_ count: Int) -> Int {
        min(max(count, visibleResults.lowerBound), visibleResults.upperBound)
    }

    /// When a row shows its second line (a path, a URL, what Return does).
    public enum Subtext: String, CaseIterable, Sendable {
        case always, selected, never
    }

    public enum Screen: String, CaseIterable, Sendable {
        /// The screen the mouse is on: the standard, and how Reach always worked.
        case mouse
        /// The screen with the menu bar.
        case main
        /// The screen with the front app's window; the mouse screen when there is none.
        case activeWindow
    }

    /// The index in `screens` to show the bar on. `screens[0]` has the menu bar,
    /// as in `NSScreen.screens`. All frames are in one coordinate space.
    public static func screen(_ choice: Screen, screens: [CGRect], mouse: CGPoint, activeWindow: CGRect?) -> Int? {
        guard !screens.isEmpty else { return nil }
        let underMouse = screens.firstIndex { $0.contains(mouse) } ?? 0
        switch choice {
        case .mouse:
            return underMouse
        case .main:
            return 0
        case .activeWindow:
            guard let window = activeWindow else { return underMouse }
            // The screen that holds most of the window, as macOS decides for a window between two screens.
            let areas = screens.map { screen -> CGFloat in
                let overlap = screen.intersection(window)
                return overlap.isNull ? 0 : overlap.width * overlap.height
            }
            guard let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 else { return underMouse }
            return best
        }
    }
}
