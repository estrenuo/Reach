import SwiftUI

/// Sizes of the launcher, on the 4 pt grid. The panel's height follows the rows.
enum LauncherLayout {
    static let width: CGFloat = 720
    static let fieldHeight: CGFloat = 56
    static let rowHeight: CGFloat = 48
    static let iconSize: CGFloat = 32
    static let markSize: CGFloat = 44

    /// Browsing: a fixed-height list of short rows, the Preview, and a footer.
    static let browseRows = 12
    static let compactRowHeight: CGFloat = 32
    static let compactIconSize: CGFloat = 24
    static let listWidth: CGFloat = 360
    static let previewIconSize: CGFloat = 192
    static let footerHeight: CGFloat = 20

    static func height(rows: Int) -> CGFloat {
        Space.md * 2 + fieldHeight + (rows > 0 ? Space.sm + CGFloat(rows) * rowHeight : 0)
    }

    static var browseHeight: CGFloat {
        Space.md * 2 + fieldHeight + Space.sm + CGFloat(browseRows) * compactRowHeight + Space.sm + footerHeight
    }

    /// The action panel: a header with the result above the browse layout.
    static var actionsHeight: CGFloat { browseHeight - fieldHeight + filterHeight + markSize + Space.sm }
    /// The action panel's filter field: lower than the search field, under the header.
    static let filterHeight: CGFloat = 40

    @MainActor static func height(for model: LauncherModel) -> CGFloat {
        if model.actions != nil { return actionsHeight }
        if model.viewer != nil { return browseHeight }
        return model.browsing != nil ? browseHeight : height(rows: model.results.count)
    }
}

struct LauncherView: View {
    @Bindable var model: LauncherModel
    @FocusState private var fieldFocused: Bool
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    private var themes = LauncherThemeStore.shared

    var body: some View {
        Group {
            if let viewer = model.viewer {
                ClipboardViewerView(model: model, viewer: viewer)
            } else if let actions = model.actions {
                ActionPanelView(model: model, panel: actions)
            } else {
                search
            }
        }
        .padding(Space.md)
        .frame(width: LauncherLayout.width, height: LauncherLayout.height(for: model), alignment: .top)
        .launcherSurface(themes.theme)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Launcher")
        .onAppear {
            model.openSettings = {
                NSApp.activate()
                openSettings()
            }
            model.openSnippets = {
                NSApp.activate()
                openWindow(id: "main")
            }
        }
        .onChange(of: model.showCount, initial: true) {
            fieldFocused = true
            appeared = false
            withAnimation(.easeOut(duration: Motion.appear)) { appeared = true }
        }
    }

    private static func caretToEnd() {
        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
    }

    private var search: some View {
        VStack(spacing: Space.sm) {
            HStack(spacing: Space.md) {
                HStack(spacing: Space.sm) {
                    TextField("Search", text: $model.query)
                        .textFieldStyle(.plain)
                        .font(LauncherStyle(theme: themes.theme).queryFont)
                        .foregroundStyle(LauncherStyle(theme: themes.theme).text ?? .primary)
                        .focused($fieldFocused)
                        // Back from the action panel: focus, then the cursor after the query,
                        // since focusing a field selects all of its text.
                        .onAppear {
                            DispatchQueue.main.async {
                                fieldFocused = true
                                DispatchQueue.main.async(execute: Self.caretToEnd)
                            }
                        }
                        // After SwiftUI has put the rewritten text in the field.
                        .onChange(of: model.queryRewrites) { DispatchQueue.main.async(execute: Self.caretToEnd) }
                        .accessibilityLabel("Launcher, search field")
                    if !model.buffer.isEmpty {
                        BufferView(items: model.buffer.items)
                    }
                }
                .padding(.horizontal, Space.lg)
                .frame(height: LauncherLayout.fieldHeight)
                .background(.quinary, in: RoundedRectangle(cornerRadius: LauncherStyle(theme: themes.theme).innerRadius, style: .continuous))
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: LauncherLayout.markSize, height: LauncherLayout.markSize)
                    .accessibilityHidden(true)
            }
            if model.browsing != nil {
                BrowseView(model: model)
            } else if !model.results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                        ResultRow(result: result, index: index, count: model.results.count,
                                  selected: index == model.selection, error: model.errors[result.id])
                            .onContinuousHover { phase in
                                if case .active = phase { model.select(index) }
                            }
                            .onTapGesture { model.open(at: index) }
                            .accessibilityAction(named: "Open") { model.open(at: index) }
                    }
                }
            }
        }
    }
}

struct ResultRow: View {
    let result: LaunchResult
    let index: Int
    let count: Int
    let selected: Bool
    let error: String?
    /// Short rows for the folder listing while browsing.
    var compact = false
    @Environment(\.launcherStyle) private var style

    private var iconSize: CGFloat { compact ? LauncherLayout.compactIconSize : LauncherLayout.iconSize }

    private var subtitle: String? {
        if let error { return error }
        return selected && !result.subtitle.isEmpty ? result.subtitle : nil
    }

    var body: some View {
        HStack(spacing: Space.md) {
            IconCache.image(for: result.icon)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(selected ? style.onSelection : Palette.accentText)
            VStack(alignment: .leading, spacing: 0) {
                Text(result.title)
                    .font(compact ? style.compactFont : style.rowFont)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let subtitle {
                    Text(subtitle)
                        .font(style.subtitleFont)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .opacity(0.8)
                }
            }
            Spacer(minLength: Space.sm)
            if !result.badge.isEmpty {
                Text(result.badge)
                    .font(.callout)
                    .foregroundStyle(selected ? AnyShapeStyle(style.onSelection.opacity(0.8)) : AnyShapeStyle(.secondary))
            }
            if result.isOpenable, selected || index < LauncherModel.maxResults {
                Text(selected ? "↩" : "⌘\(index + 1)")
                    .font(compact ? style.compactFont : style.rowFont)
                    .foregroundStyle(selected ? AnyShapeStyle(style.onSelection) : AnyShapeStyle(.secondary))
            }
        }
        .foregroundStyle(selected ? style.onSelection : style.text ?? .primary)
        .padding(.horizontal, Space.md)
        .frame(height: compact ? LauncherLayout.compactRowHeight : LauncherLayout.rowHeight)
        .background(selected ? style.selection : .clear,
                    in: RoundedRectangle(cornerRadius: style.innerRadius, style: .continuous))
        .contentShape(Rectangle())
        .help(tooltip)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var tooltip: String {
        if result.isFolder && compact { return "Press → to browse this folder, ↩ to open it in Finder" }
        return result.subtitle.isEmpty ? result.title : result.subtitle
    }

    private var accessibilityText: String {
        let parts = [result.kindLabel, result.badge, result.title, error ?? result.subtitle].filter { !$0.isEmpty }
        return parts.joined(separator: ", ") + ", result \(index + 1) of \(count)"
    }
}
