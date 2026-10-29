import AppKit
import ReachKit
import SwiftUI

/// The popover for one part of the preview (S-033). On an own theme it changes
/// the theme at once; on a built-in one it offers a copy to change instead.
struct ThemeEditor: View {
    let part: LauncherTheme.Part
    @Bindable private var themes = LauncherThemeStore.shared

    var body: some View {
        Group {
            if themes.theme.isBuiltIn {
                builtIn
            } else {
                Form { fields }
                    .formStyle(.grouped)
                    .scrollDisabled(true)
            }
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var builtIn: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("\(themes.theme.name) is built in")
                .font(.headline)
            Text("Duplicate it to change \(part.title). The copy is picked, and your changes show at once.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Duplicate to Edit") { themes.duplicate(themes.theme) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.lg)
    }

    @ViewBuilder
    private var fields: some View {
        switch part {
        case .background:
            Section("Background") {
                Picker("Appearance", selection: theme.mode) {
                    Text("Follow the Mac").tag(LauncherTheme.Mode.system)
                    Text("Light").tag(LauncherTheme.Mode.light)
                    Text("Dark").tag(LauncherTheme.Mode.dark)
                }
                Picker("Surface", selection: theme.surface) {
                    Text("Glass").tag(LauncherTheme.Surface.glass)
                    Text("Clear Glass").tag(LauncherTheme.Surface.clearGlass)
                    Text("Solid").tag(LauncherTheme.Surface.solid)
                }
                OptionalColor(title: "Tint", color: theme.tint, fallback: Color.accentColor.opacity(0.3))
                Slider(value: theme.cornerRadius, in: LauncherTheme.cornerRadii, step: 4) {
                    Text("Corners")
                }
            }
        case .searchField:
            Section("Search Field") {
                FontPicker(name: theme.fontName)
                Slider(value: theme.querySize, in: LauncherTheme.querySizes, step: 1) {
                    Text("Size")
                }
                OptionalColor(title: "Text color", color: theme.textColor, fallback: .primary)
            }
        case .results:
            Section("Results") {
                OptionalColor(title: "Selection color", color: theme.selectionColor, fallback: Palette.accent,
                              off: "Uses the accent color")
                FontPicker(name: theme.fontName)
                Slider(value: theme.rowSize, in: LauncherTheme.rowSizes, step: 1) {
                    Text("Size")
                }
                OptionalColor(title: "Text color", color: theme.textColor, fallback: .primary)
            }
        }
    }

    /// The picked theme, read and written through the store.
    private var theme: Binding<LauncherTheme> {
        Binding(get: { themes.theme }, set: { themes.update($0) })
    }
}

/// A color a theme may leave unset: a switch, and a color well while it is on.
private struct OptionalColor: View {
    let title: String
    @Binding var color: ThemeColor?
    let fallback: Color
    var off = "Uses the system color"

    var body: some View {
        Toggle(isOn: Binding(get: { color != nil }, set: { color = $0 ? ThemeColor(fallback) : nil })) {
            Text(title)
            if color == nil { Text(off) }
        }
        if color != nil {
            ColorPicker("Color", selection: Binding(
                get: { color.map(Color.init) ?? fallback },
                set: { color = ThemeColor($0) }))
        }
    }
}

/// The system font or one of the Mac's font families.
private struct FontPicker: View {
    @Binding var name: String?
    private static let families = NSFontManager.shared.availableFontFamilies

    var body: some View {
        Picker("Font", selection: $name) {
            Text("System").tag(String?.none)
            Divider()
            ForEach(Self.families, id: \.self) { family in
                Text(family).tag(Optional(family))
            }
        }
    }
}
