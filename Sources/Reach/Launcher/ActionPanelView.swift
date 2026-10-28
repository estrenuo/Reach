import SwiftUI

/// The action panel: the result in a header, a filter field, the actions
/// (or apps, after Open With…) on the left, the Preview on the right, and
/// what the selected action does in the footer.
struct ActionPanelView: View {
    let model: LauncherModel
    @Bindable var panel: ActionPanel
    @FocusState private var filterFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            header
            TextField(panel.choosingApp ? "Filter apps" : "Filter actions", text: $panel.filter)
                .textFieldStyle(.plain)
                .font(.title2)
                .focused($filterFocused)
                // A tick later: on appear the field is not in the window yet,
                // and focus set then is lost, so typing went nowhere.
                .onAppear { DispatchQueue.main.async { filterFocused = true } }
                .accessibilityLabel(panel.choosingApp ? "Filter apps" : "Filter actions")
                .padding(.horizontal, Space.md)
                .frame(height: LauncherLayout.filterHeight)
                .background(.quinary, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            HStack(alignment: .top, spacing: Space.md) {
                list
                    .frame(width: LauncherLayout.listWidth)
                Group {
                    if let text = panel.text {
                        // Selected text previews as itself.
                        ScrollView {
                            Text(text)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityLabel("Preview, \(text)")
                    } else {
                        PreviewPane(result: panel.target)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: CGFloat(LauncherLayout.browseRows) * LauncherLayout.compactRowHeight)
            Text(panel.footer)
                .font(.callout)
                .foregroundStyle(panel.failure == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, Space.md)
                .frame(height: LauncherLayout.footerHeight)
        }
    }

    private var isSymbol: Bool {
        if case .symbol = panel.target.icon { true } else { false }
    }

    private var header: some View {
        HStack(spacing: Space.md) {
            IconCache.image(for: panel.target.icon)
                .resizable()
                .scaledToFit()
                // A symbol (selected text) is drawn smaller than a file icon, inside the same square.
                .frame(width: isSymbol ? LauncherLayout.iconSize : LauncherLayout.markSize,
                       height: isSymbol ? LauncherLayout.iconSize : LauncherLayout.markSize)
                .foregroundStyle(Palette.accentText)
                .frame(width: LauncherLayout.markSize, height: LauncherLayout.markSize)
            VStack(alignment: .leading, spacing: 0) {
                Text(panel.target.title)
                    .font(.title2)
                    .lineLimit(1)
                Text(panel.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, Space.sm)
        .frame(height: LauncherLayout.markSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Actions for \(panel.target.title), \(panel.detail)")
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(panel.rows.enumerated()), id: \.element.id) { index, row in
                        ResultRow(result: row, index: index, count: panel.rows.count,
                                  selected: index == panel.selection, error: nil, compact: true)
                            .id(row.id)
                            .onContinuousHover { phase in
                                if case .active = phase { panel.select(index) }
                            }
                            .onTapGesture { model.runAction(at: index) }
                            .accessibilityAction(named: "Run") { model.runAction(at: index) }
                    }
                }
            }
            .onChange(of: panel.selection) {
                guard panel.rows.indices.contains(panel.selection) else { return }
                proxy.scrollTo(panel.rows[panel.selection].id)
            }
        }
    }
}
