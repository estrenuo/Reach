import AppKit
import ReachKit
import SwiftUI

/// The clipboard viewer in the launcher (S-026): a filter field, the clips
/// on the left, the selected clip in full on the right, and a footer.
struct ClipboardViewerView: View {
    let model: LauncherModel
    @Bindable var viewer: ClipboardViewer
    @FocusState private var filterFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.md) {
                TextField("Filter clipboard", text: $viewer.filter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 28))
                    .focused($filterFocused)
                    // A tick later, as in the action panel: on appear the field is not in the window yet.
                    .onAppear { DispatchQueue.main.async { filterFocused = true } }
                    .accessibilityLabel("Clipboard, filter field")
                    .padding(.horizontal, Space.lg)
                    .frame(height: LauncherLayout.fieldHeight)
                    .background(.quinary, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                Image(systemName: "list.clipboard")
                    .font(.system(size: 28))
                    .foregroundStyle(Palette.accentText)
                    .frame(width: LauncherLayout.markSize, height: LauncherLayout.markSize)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .top, spacing: Space.md) {
                list
                    .frame(width: LauncherLayout.listWidth)
                ClipPreview(entry: viewer.selected)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: CGFloat(LauncherLayout.browseRows) * LauncherLayout.compactRowHeight)
            Text(viewer.footer)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, Space.md)
                .frame(height: LauncherLayout.footerHeight)
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewer.rows.enumerated()), id: \.element.id) { index, row in
                        ResultRow(result: row, index: index, count: viewer.rows.count,
                                  selected: index == viewer.selection, error: nil, compact: true)
                            .id(row.id)
                            .onContinuousHover { phase in
                                if case .active = phase { viewer.select(index) }
                            }
                            .onTapGesture { model.useClip(at: index) }
                            .accessibilityAction(named: "Paste") { model.useClip(at: index) }
                    }
                }
            }
            .onChange(of: viewer.selection) {
                guard let id = viewer.selected?.row.id else { return }
                proxy.scrollTo(id)
            }
        }
    }
}

/// The right side: the clip's whole text, the image, or the copied files;
/// a hint for All Snippets and while the history is off.
private struct ClipPreview: View {
    let entry: ClipboardViewer.Entry?

    var body: some View {
        switch entry?.kind {
        case .snippets:
            hint(ClipboardViewer.snippetsHint)
        case .turnOn:
            hint(ClipboardViewer.isOff)
        case .clip(let item):
            clip(item)
        case .snippet(let snippet):
            ScrollView {
                Text(snippet.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityLabel("Preview, \(snippet.text)")
        case .noMatch, nil:
            Color.clear
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func clip(_ item: ClipboardItem) -> some View {
        switch item.clipKind {
        case .text:
            ScrollView {
                Text(item.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityLabel("Preview, \(item.text)")
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Preview, image of \(Int(image.size.width)) by \(Int(image.size.height)) points")
            }
        case .files:
            let paths = item.text.split(separator: "\n").map(String.init)
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xs) {
                    ForEach(paths, id: \.self) { path in
                        Label {
                            Text((path as NSString).abbreviatingWithTildeInPath).lineLimit(1).truncationMode(.middle)
                        } icon: {
                            IconCache.image(for: .file(path))
                                .resizable()
                                .frame(width: LauncherLayout.compactIconSize, height: LauncherLayout.compactIconSize)
                        }
                        .help(path)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityLabel("Preview, \(paths.count) files")
        }
    }
}
