import ReachKit
import SwiftUI

/// Settings > Appearance (S-032, S-033): a preview of the launcher on top, the
/// themes below it, then the accent color. A pick shows in the preview and the
/// real bar at once. Clicking a part of the preview edits it in a popover.
struct AppearanceSettings: View {
    @Bindable private var themes = LauncherThemeStore.shared
    @Bindable private var store = ThemeStore.shared
    @Bindable private var options = LauncherOptionsStore.shared
    @State private var renaming: LauncherTheme?
    @State private var newName = ""
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        Section {
            LauncherPreview(theme: themes.theme, picture: themes.previewPicture()) { themes.editing = $0 }
                .popover(item: $themes.editing, arrowEdge: .bottom) { part in
                    ThemeEditor(part: part)
                }
            Toggle("Show on Desktop Picture", isOn: $themes.previewOnDesktop)
        } footer: {
            Text("Click a part of the preview to change it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Theme") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.lg), count: 3), spacing: Space.lg) {
                ForEach(themes.all) { theme in
                    ThemeThumbnail(theme: theme, selected: themes.themeID == theme.id) {
                        themes.themeID = theme.id
                    }
                    .contextMenu { menu(for: theme) }
                }
            }
            .padding(.vertical, Space.xs)
            HStack {
                Button("Launcher Options…") { options.isEditing = true }
                    .help("Set how many results show, their subtext and shortcuts, and which screen the launcher uses")
                Spacer()
                Button("Duplicate Theme") { themes.duplicate(themes.theme) }
                    .help("Make an own copy of \(themes.theme.name) to change")
            }
        }
        .sheet(isPresented: $options.isEditing) { LauncherOptionsSheet() }
        .alert("Rename Theme", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") { rename() }
            Button("Cancel", role: .cancel) {}
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

    @ViewBuilder
    private func menu(for theme: LauncherTheme) -> some View {
        Button("Duplicate") { themes.duplicate(theme) }
        if !theme.isBuiltIn {
            Button("Rename…") {
                newName = theme.name
                renaming = theme
            }
            Divider()
            Button("Delete") { delete(theme) }
        }
    }

    private func rename() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard var theme = renaming, !name.isEmpty else { return }
        theme.name = name
        themes.update(theme)
    }

    /// Delete can be undone with ⌘Z, so it does not ask first.
    private func delete(_ theme: LauncherTheme) {
        guard let gone = themes.delete(theme.id) else { return }
        undoManager?.registerUndo(withTarget: themes) { store in
            store.restore(gone.theme, at: gone.index, pick: gone.wasPicked)
        }
        undoManager?.setActionName("Delete Theme")
    }
}

extension LauncherTheme.Part: Identifiable {
    public var id: String { rawValue }

    /// "the search field": for tooltips and VoiceOver.
    var title: String {
        switch self {
        case .background: "the background"
        case .searchField: "the search field"
        case .results: "the results"
        }
    }
}

/// A drawn launcher in a theme: the query "co" and three apps, the first one
/// selected. A picture, not the real bar, so it never takes focus. Clicking a
/// part tells `edit`.
private struct LauncherPreview: View {
    let theme: LauncherTheme
    let picture: NSImage?
    let edit: (LauncherTheme.Part) -> Void

    private static let rows: [MockLauncher.Row] = [
        .init(name: "Contacts", path: "/System/Applications/Contacts.app", key: "↩"),
        .init(name: "Console", path: "/System/Applications/Utilities/Console.app", key: "⌘2"),
        .init(name: "ColorSync Utility", path: "/System/Applications/Utilities/ColorSync Utility.app", key: "⌘3"),
    ]

    var body: some View {
        MockLauncher(theme: theme, rows: Self.rows, scale: 1, edit: edit)
            .frame(width: 480)
            .padding(.vertical, Space.xxl)
            .frame(maxWidth: .infinity)
            .background { Backdrop(picture: picture) }
            .clipShape(RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
            .accessibilityElement(children: .contain)
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
                MockLauncher(theme: theme, rows: [.init(name: "Contacts", path: "/System/Applications/Contacts.app", key: "↩")],
                             scale: 0.7, edit: nil)
                    .padding(Space.md)
                    .frame(maxWidth: .infinity)
                    .background { Backdrop(picture: LauncherThemeStore.sampleThumbnail) }
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(selected ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.separator),
                                           lineWidth: selected ? 3 : 1)
                    }
                VStack(alignment: .leading, spacing: 0) {
                    Text(theme.name).font(.callout.weight(.medium)).lineLimit(1)
                    Text(theme.isBuiltIn ? theme.summary : "Own theme, \(theme.summary.lowercased())")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .help(theme.name)
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

/// The launcher drawn small: a query line and result rows, in a theme's look.
/// With `edit`, each part outlines on hover and opens its editor on a click.
private struct MockLauncher: View {
    struct Row {
        let name: String
        let path: String
        let key: String
    }

    let theme: LauncherTheme
    let rows: [Row]
    let scale: CGFloat
    let edit: ((LauncherTheme.Part) -> Void)?
    @Environment(\.colorScheme) private var outer

    var body: some View {
        let style = LauncherStyle(theme: theme)
        VStack(spacing: Space.sm * scale) {
            HStack(spacing: Space.sm * scale) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                Text("co").foregroundStyle(style.text ?? .primary)
                Spacer(minLength: 0)
            }
            .font(scaled(theme.querySize, style))
            .padding(.horizontal, Space.lg * scale)
            .frame(height: 48 * scale)
            .background(.quinary, in: RoundedRectangle(cornerRadius: style.innerRadius * scale, style: .continuous))
            .part(.searchField, edit: edit, radius: style.innerRadius * scale)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    self.row(row, selected: index == 0, style: style)
                }
            }
            .part(.results, edit: edit, radius: style.innerRadius * scale)
        }
        .padding(Space.md * scale)
        .contentShape(Rectangle())
        .part(.background, edit: edit, radius: theme.cornerRadius * scale)
        .launcherSurface(theme, scale: scale)
        .environment(\.colorScheme, theme.mode.colorScheme ?? outer)
    }

    private func scaled(_ size: Double, _ style: LauncherStyle) -> Font {
        let size = size * scale
        return theme.fontName.map { .custom($0, size: size) } ?? .system(size: size)
    }

    private func row(_ row: Row, selected: Bool, style: LauncherStyle) -> some View {
        HStack(spacing: Space.sm * scale) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: row.path))
                .resizable()
                .frame(width: 28 * scale, height: 28 * scale)
            Text(row.name).font(scaled(theme.rowSize, style))
            Spacer(minLength: 0)
            Text(row.key)
                .font(scaled(theme.rowSize - 2, style))
                .foregroundStyle(selected ? AnyShapeStyle(style.onSelection.opacity(0.8)) : AnyShapeStyle(.secondary))
        }
        .foregroundStyle(selected ? style.onSelection : style.text ?? .primary)
        .padding(.horizontal, Space.sm * scale)
        .frame(height: 40 * scale)
        .background(selected ? style.selection : .clear,
                    in: RoundedRectangle(cornerRadius: style.innerRadius * scale, style: .continuous))
    }
}

private extension View {
    /// A part of the preview people can click to edit. Without `edit` it is only a picture.
    @ViewBuilder
    func part(_ part: LauncherTheme.Part, edit: ((LauncherTheme.Part) -> Void)?, radius: CGFloat) -> some View {
        if let edit {
            modifier(EditablePart(part: part, edit: edit, radius: radius))
        } else {
            self.allowsHitTesting(false)
        }
    }
}

private struct EditablePart: ViewModifier {
    let part: LauncherTheme.Part
    let edit: (LauncherTheme.Part) -> Void
    let radius: CGFloat
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.accent, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .opacity(hovered ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onHover { hovered = $0 }
            .onTapGesture { edit(part) }
            .help("Change \(part.title)")
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Change \(part.title)")
            .accessibilityAction { edit(part) }
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
