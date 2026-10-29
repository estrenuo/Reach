import Foundation

/// How the launcher looks (S-032): light, dark or following the Mac, on glass,
/// clear glass or a solid surface. An own theme (S-033) also sets colors, the
/// font and the corners. The accent color is picked apart and goes with every
/// theme that leaves the selection color unset.
public struct LauncherTheme: Identifiable, Hashable, Sendable, Codable {
    public enum Mode: String, Sendable, Codable, CaseIterable {
        case system, light, dark
    }

    public enum Surface: String, Sendable, Codable, CaseIterable {
        /// Liquid Glass, as macOS draws it.
        case glass
        /// Clear glass: more of what is behind shows through.
        case clearGlass
        /// An opaque window background, for people who find glass busy.
        case solid
    }

    /// The three parts of the preview that open an editor when clicked.
    public enum Part: String, Sendable, CaseIterable {
        case background, searchField, results
    }

    public var id: String
    public var name: String
    public var mode: Mode
    public var surface: Surface
    /// Built-in themes cannot be changed; people duplicate one instead.
    public var isBuiltIn: Bool
    /// A color laid over the surface. Nil: the surface as it is.
    public var tint: ThemeColor?
    /// The text of the query and the rows. Nil: the system's text color.
    public var textColor: ThemeColor?
    /// The selected row. Nil: the accent color.
    public var selectionColor: ThemeColor?
    /// A font family. Nil: the system font.
    public var fontName: String?
    public var querySize: Double
    public var rowSize: Double
    public var cornerRadius: Double

    public static let querySizes: ClosedRange<Double> = 20...40
    public static let rowSizes: ClosedRange<Double> = 12...20
    public static let cornerRadii: ClosedRange<Double> = 0...32

    public init(id: String, name: String, mode: Mode, surface: Surface, isBuiltIn: Bool = true,
                tint: ThemeColor? = nil, textColor: ThemeColor? = nil, selectionColor: ThemeColor? = nil,
                fontName: String? = nil, querySize: Double = 28, rowSize: Double = 15, cornerRadius: Double = 24) {
        self.id = id
        self.name = name
        self.mode = mode
        self.surface = surface
        self.isBuiltIn = isBuiltIn
        self.tint = tint
        self.textColor = textColor
        self.selectionColor = selectionColor
        self.fontName = fontName
        self.querySize = querySize
        self.rowSize = rowSize
        self.cornerRadius = cornerRadius
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

    /// The theme with this id among the built-in and own themes; the standard one for an id that is gone.
    public static func named(_ id: String?, in own: [LauncherTheme] = []) -> LauncherTheme {
        (all + own).first { $0.id == id } ?? standard
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

    /// An own copy to change, named "<name> Copy" (then "Copy 2", ...) so it differs from `taken`.
    public func duplicate(id: String, taken: [String]) -> LauncherTheme {
        var copy = self
        copy.id = id
        copy.name = Self.copyName(of: name, taken: Set(taken))
        copy.isBuiltIn = false
        return copy
    }

    static func copyName(of name: String, taken: Set<String>) -> String {
        let base = "\(name) Copy"
        if !taken.contains(base) { return base }
        var number = 2
        while taken.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }

    /// Sizes inside their ranges, so a saved value from elsewhere cannot break the bar.
    public func clamped() -> LauncherTheme {
        var theme = self
        theme.querySize = querySize.clamped(to: Self.querySizes)
        theme.rowSize = rowSize.clamped(to: Self.rowSizes)
        theme.cornerRadius = cornerRadius.clamped(to: Self.cornerRadii)
        return theme
    }

    // Saved themes may miss fields that a later version adds: those get their defaults.
    private enum CodingKeys: String, CodingKey {
        case id, name, mode, surface, tint, textColor, selectionColor, fontName, querySize, rowSize, cornerRadius
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id),
                  name: try c.decode(String.self, forKey: .name),
                  mode: (try? c.decode(Mode.self, forKey: .mode)) ?? .system,
                  surface: (try? c.decode(Surface.self, forKey: .surface)) ?? .glass,
                  isBuiltIn: false,
                  tint: try? c.decodeIfPresent(ThemeColor.self, forKey: .tint),
                  textColor: try? c.decodeIfPresent(ThemeColor.self, forKey: .textColor),
                  selectionColor: try? c.decodeIfPresent(ThemeColor.self, forKey: .selectionColor),
                  fontName: try? c.decodeIfPresent(String.self, forKey: .fontName),
                  querySize: (try? c.decodeIfPresent(Double.self, forKey: .querySize)) ?? 28,
                  rowSize: (try? c.decodeIfPresent(Double.self, forKey: .rowSize)) ?? 15,
                  cornerRadius: (try? c.decodeIfPresent(Double.self, forKey: .cornerRadius)) ?? 24)
        self = clamped()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(mode, forKey: .mode)
        try c.encode(surface, forKey: .surface)
        try c.encodeIfPresent(tint, forKey: .tint)
        try c.encodeIfPresent(textColor, forKey: .textColor)
        try c.encodeIfPresent(selectionColor, forKey: .selectionColor)
        try c.encodeIfPresent(fontName, forKey: .fontName)
        try c.encode(querySize, forKey: .querySize)
        try c.encode(rowSize, forKey: .rowSize)
        try c.encode(cornerRadius, forKey: .cornerRadius)
    }
}

/// A color in sRGB, 0 to 1, saved with an own theme.
public struct ThemeColor: Hashable, Sendable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Relative luminance, as WCAG defines it.
    public var luminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// Black text reads better than white on this color. 0.179 is where both have the same contrast.
    public var wantsDarkText: Bool { luminance > 0.179 }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
