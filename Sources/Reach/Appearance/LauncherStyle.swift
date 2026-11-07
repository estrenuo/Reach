import ReachKit
import SwiftUI

/// What a theme means for the launcher's views: fonts, colors and corners
/// (S-033). The bar and the preview in Settings both read it from the
/// environment, so they always look the same.
struct LauncherStyle {
    let theme: LauncherTheme

    var queryFont: Font { font(theme.querySize) }
    var rowFont: Font { font(theme.rowSize) }
    /// The short rows while browsing, two points smaller.
    var compactFont: Font { font(theme.rowSize - 2) }
    var subtitleFont: Font { font(theme.rowSize - 3) }

    /// The text of the query and the rows; nil leaves the system's color.
    var text: Color? { theme.textColor.map(Color.init) }
    var selection: Color { theme.selectionColor.map(Color.init) ?? Palette.accent }
    var onSelection: Color {
        guard let color = theme.selectionColor else { return Palette.onAccent }
        return color.wantsDarkText ? .black : .white
    }

    var panelRadius: CGFloat { theme.cornerRadius }
    /// Rows and the search field sit `Space.md` inside the panel.
    var innerRadius: CGFloat { max(theme.cornerRadius - Space.md, 4) }

    private func font(_ size: Double) -> Font {
        if let name = theme.fontName { return .custom(name, size: size) }
        return .system(size: size)
    }
}

extension EnvironmentValues {
    @Entry var launcherStyle = LauncherStyle(theme: .standard)
}

extension Color {
    init(_ color: ThemeColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}

extension ThemeColor {
    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(red: ns.redComponent, green: ns.greenComponent, blue: ns.blueComponent, alpha: ns.alphaComponent)
    }
}

extension View {
    /// The launcher's background in a theme: its surface, tint and corners,
    /// for the bar and its previews. Also puts the theme's style in the environment.
    func launcherSurface(_ theme: LauncherTheme, scale: CGFloat = 1) -> some View {
        modifier(LauncherSurface(theme: theme, scale: scale))
            .environment(\.launcherStyle, LauncherStyle(theme: theme))
    }
}

private struct LauncherSurface: ViewModifier {
    let theme: LauncherTheme
    let scale: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.cornerRadius * scale, style: .continuous)
        let tint = theme.tint.map(Color.init)
        switch theme.surface {
        case .glass:
            content.glassEffect(.regular.tint(tint), in: shape)
        case .clearGlass:
            content.glassEffect(.clear.tint(tint), in: shape)
        case .solid:
            content
                .background(tint ?? Color(nsColor: .windowBackgroundColor), in: shape)
                .overlay(shape.strokeBorder(.separator, lineWidth: 1))
        }
    }
}
