import SwiftUI

/// Sizes of the launcher, on the 4 pt grid. The panel's height follows the rows.
enum LauncherLayout {
    static let width: CGFloat = 720
    static let fieldHeight: CGFloat = 56
    static let rowHeight: CGFloat = 48
    static let iconSize: CGFloat = 32
    static let markSize: CGFloat = 44

    static func height(rows: Int) -> CGFloat {
        Space.md * 2 + fieldHeight + (rows > 0 ? Space.sm + CGFloat(rows) * rowHeight : 0)
    }
}

struct LauncherView: View {
    @Bindable var model: LauncherModel
    @FocusState private var fieldFocused: Bool
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: Space.sm) {
            HStack(spacing: Space.md) {
                TextField("Search", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 28))
                    .focused($fieldFocused)
                    .accessibilityLabel("Launcher, search field")
                    .padding(.horizontal, Space.lg)
                    .frame(height: LauncherLayout.fieldHeight)
                    .background(.quinary, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: LauncherLayout.markSize, height: LauncherLayout.markSize)
                    .accessibilityHidden(true)
            }
            if !model.results.isEmpty {
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
        .padding(Space.md)
        .frame(width: LauncherLayout.width, height: LauncherLayout.height(rows: model.results.count), alignment: .top)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.panel, style: .continuous))
        .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Launcher")
        .onAppear {
            model.openSettings = {
                NSApp.activate()
                openSettings()
            }
        }
        .onChange(of: model.showCount, initial: true) {
            fieldFocused = true
            appeared = false
            withAnimation(.easeOut(duration: Motion.appear)) { appeared = true }
        }
    }
}

struct ResultRow: View {
    let result: LaunchResult
    let index: Int
    let count: Int
    let selected: Bool
    let error: String?

    private var subtitle: String? {
        if let error { return error }
        return selected && !result.subtitle.isEmpty ? result.subtitle : nil
    }

    var body: some View {
        HStack(spacing: Space.md) {
            IconCache.image(for: result.icon)
                .resizable()
                .scaledToFit()
                .frame(width: LauncherLayout.iconSize, height: LauncherLayout.iconSize)
                .foregroundStyle(selected ? Palette.onAccent : Palette.accentText)
            VStack(alignment: .leading, spacing: 0) {
                Text(result.title)
                    .font(.title3)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .opacity(0.8)
                }
            }
            Spacer(minLength: Space.sm)
            if result.isOpenable {
                Text(selected ? "↩" : "⌘\(index + 1)")
                    .font(.title3)
                    .foregroundStyle(selected ? AnyShapeStyle(Palette.onAccent) : AnyShapeStyle(.secondary))
            }
        }
        .foregroundStyle(selected ? Palette.onAccent : .primary)
        .padding(.horizontal, Space.md)
        .frame(height: LauncherLayout.rowHeight)
        .background(selected ? Palette.accent : .clear,
                    in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .contentShape(Rectangle())
        .help(result.subtitle.isEmpty ? result.title : result.subtitle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var accessibilityText: String {
        let parts = [result.kindLabel, result.title, error ?? result.subtitle].filter { !$0.isEmpty }
        return parts.joined(separator: ", ") + ", result \(index + 1) of \(count)"
    }
}
