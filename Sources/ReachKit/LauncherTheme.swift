import Foundation

/// How the launcher looks (S-032): light, dark or following the Mac, on glass,
/// clear glass or a solid surface. The accent color is picked apart and goes
/// with every theme. Colors, font and corners per theme arrive in S-033.
public struct LauncherTheme: Identifiable, Hashable, Sendable {
    public enum Mode: String, Sendable {
        case system, light, dark
    }

    public enum Surface: String, Sendable {
        /// Liquid Glass, as macOS draws it.
        case glass
        /// Clear glass: more of what is behind shows through.
        case clearGlass
        /// An opaque window background, for people who find glass busy.
        case solid
    }

    public let id: String
    public let name: String
    public let mode: Mode
    public let surface: Surface

    public init(id: String, name: String, mode: Mode, surface: Surface) {
        self.id = id
        self.name = name
        self.mode = mode
        self.surface = surface
    }

    /// The built-in themes, in the order Settings shows them.
    public static let all: [LauncherTheme] = [
        LauncherTheme(id: "reach", name: "Reach", mode: .system, surface: .glass),
        LauncherTheme(id: "reach-light", name: "Reach Light", mode: .light, surface: .glass),
        LauncherTheme(id: "reach-dark", name: "Reach Dark", mode: .dark, surface: .glass),
        LauncherTheme(id: "clear", name: "Clear", mode: .system, surface: .clearGlass),
        LauncherTheme(id: "solid-light", name: "Solid Light", mode: .light, surface: .solid),
        LauncherTheme(id: "solid-dark", name: "Solid Dark", mode: .dark, surface: .solid),
    ]

    public static let standard = all[0]

    /// The theme with this id; the standard one for an id that is gone.
    public static func named(_ id: String?) -> LauncherTheme {
        all.first { $0.id == id } ?? standard
    }

    /// "Glass, follows the Mac": the line under the name in Settings.
    public var summary: String {
        let look = switch surface {
        case .glass: "Glass"
        case .clearGlass: "Clear glass"
        case .solid: "Solid"
        }
        let light = switch mode {
        case .system: "follows the Mac"
        case .light: "light"
        case .dark: "dark"
        }
        return "\(look), \(light)"
    }
}
