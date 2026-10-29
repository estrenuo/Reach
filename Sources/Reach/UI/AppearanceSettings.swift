import ReachKit
import SwiftUI

/// Settings > Appearance (S-032): a preview of the launcher on top, the themes
/// below it, then the accent color. A pick shows in the preview and the real bar at once.
struct AppearanceSettings: View {
    @Bindable private var themes = LauncherThemeStore.shared
    @Bindable private var store = ThemeStore.shared

    var body: some View {
        Section {
            LauncherPreview(theme: themes.theme, picture: themes.previewPicture())
            Toggle("Show on Desktop Picture", isOn: $themes.previewOnDesktop)
        }
        Section("Theme") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.lg), count: 3), spacing: Space.lg) {
                ForEach(LauncherTheme.all) { theme in
                    ThemeThumbnail(theme: theme, selected: themes.themeID == theme.id) {
                        themes.themeID = theme.id
                    }
                }
            }
            .padding(.vertical, Space.xs)
        }
        Section {
            LabeledContent("Accent color") {
                VStack(alignment: .trailing, spacing: Space.xs) {
                    HStack(spacing: Space.sm) {
                        ForEach(Theme.all) { theme in
                            AccentSwatch(theme: theme, selected: store.themeID == theme.id) {
                                store.themeID = theme.id
                            }
                        }
                    }
                    Text(store.theme.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// A drawn launcher in a theme: the query "co" and three apps, the first one
/// selected. A picture, not the real bar, so it never takes focus.
private struct LauncherPreview: View {
    let theme: LauncherTheme
    let picture: NSImage?

    private static let rows: [(name: String, path: String, key: String)] = [
        ("Contacts", "/System/Applications/Contacts.app", "↩"),
        ("Console", "/System/Applications/Utilities/Console.app", "⌘2"),
        ("ColorSync Utility", "/System/Applications/Utilities/ColorSync Utility.app", "⌘3"),
    ]

    var body: some View {
        MockLauncher(theme: theme, rows: Self.rows, scale: 1)
            .frame(width: 480)
            .padding(.vertical, Space.xxl)
            .frame(maxWidth: .infinity)
            .background { Backdrop(picture: picture) }
            .clipShape(RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Preview of the \(theme.name) theme")
    }
}

/// One theme to pick: a small launcher in its look, its name, and a line on what it is.
private struct ThemeThumbnail: View {
    let theme: LauncherTheme
    let selected: Bool
    let choose: () -> Void

    private let shape = RoundedRectangle(cornerRadius: Radius.row, style: .continuous)

    var body: some View {
        Button(action: choose) {
            VStack(alignment: .leading, spacing: Space.sm) {
                MockLauncher(theme: theme, rows: [("Contacts", "/System/Applications/Contacts.app", "↩")], scale: 0.7)
                    .padding(Space.md)
                    .frame(maxWidth: .infinity)
                    .background { Backdrop(picture: LauncherThemeStore.sampleThumbnail) }
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(selected ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.separator),
                                           lineWidth: selected ? 3 : 1)
                    }
                VStack(alignment: .leading, spacing: 0) {
                    Text(theme.name).font(.callout.weight(.medium))
                    Text(theme.summary).font(.caption).foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Use the \(theme.name) theme for the launcher")
        .accessibilityLabel("\(theme.name), \(theme.summary)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// What a preview sits on: a picture, or the plain window background.
private struct Backdrop: View {
    let picture: NSImage?

    var body: some View {
        if let picture {
            Image(nsImage: picture).resizable().scaledToFill()
        } else {
            Rectangle().fill(.background.secondary)
        }
    }
}

/// The launcher drawn small: a query line and result rows, in a theme's
/// mode and surface, with the first row in the accent color.
private struct MockLauncher: View {
    let theme: LauncherTheme
    let rows: [(name: String, path: String, key: String)]
    let scale: CGFloat
    @Environment(\.colorScheme) private var outer

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.sm * scale) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                Text("co")
                Spacer(minLength: 0)
            }
            .font(.system(size: 20 * scale))
            .padding(.horizontal, Space.lg * scale)
            .frame(height: 44 * scale)
            Divider()
            VStack(spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    self.row(row, selected: index == 0)
                }
            }
            .padding(Space.sm * scale)
        }
        .foregroundStyle(.primary)
        .launcherSurface(theme.surface, cornerRadius: Radius.panel * scale)
        .environment(\.colorScheme, theme.mode.colorScheme ?? outer)
    }

    private func row(_ row: (name: String, path: String, key: String), selected: Bool) -> some View {
        HStack(spacing: Space.sm * scale) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: row.path))
                .resizable()
                .frame(width: 28 * scale, height: 28 * scale)
            Text(row.name).font(.system(size: 14 * scale, weight: .medium))
            Spacer(minLength: 0)
            Text(row.key)
                .font(.system(size: 12 * scale))
                .foregroundStyle(selected ? AnyShapeStyle(Palette.onAccent.opacity(0.8)) : AnyShapeStyle(.secondary))
        }
        .foregroundStyle(selected ? AnyShapeStyle(Palette.onAccent) : AnyShapeStyle(.primary))
        .padding(.horizontal, Space.sm * scale)
        .frame(height: 40 * scale)
        .background(selected ? Palette.accent : .clear,
                    in: RoundedRectangle(cornerRadius: Radius.row * scale, style: .continuous))
    }
}

/// One color dot, like the accent row in System Settings.
private struct AccentSwatch: View {
    let theme: Theme
    let selected: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            Circle()
                .fill(fill)
                .frame(width: 16, height: 16)
                .overlay {
                    if selected {
                        Circle().fill(theme.onAccent).frame(width: 6, height: 6) // grid: ok
                    }
                }
                .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(theme.name)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var fill: AnyShapeStyle {
        if let tint = theme.tint {
            AnyShapeStyle(tint)
        } else {
            AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red],
                                          center: .center))
        }
    }
}
