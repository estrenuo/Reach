import SwiftUI

/// The launcher while browsing a path: the folder's contents on the left,
/// the Preview of the selected result on the right, its name in a footer.
struct BrowseView: View {
    @Bindable var model: LauncherModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .top, spacing: Space.md) {
                list
                    .frame(width: LauncherLayout.listWidth)
                PreviewPane(result: model.selectedResult)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: CGFloat(LauncherLayout.browseRows) * LauncherLayout.compactRowHeight)
            Text(model.selectedResult?.title ?? "")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, Space.md)
                .frame(height: LauncherLayout.footerHeight)
                .accessibilityHidden(true)
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                        ResultRow(result: result, index: index, count: model.results.count,
                                  selected: index == model.selection, error: model.errors[result.id], compact: true)
                            .id(result.id)
                            .onContinuousHover { phase in
                                if case .active = phase { model.select(index) }
                            }
                            .onTapGesture { model.open(at: index) }
                            .accessibilityAction(named: "Open") { model.open(at: index) }
                    }
                }
            }
            .scrollIndicators(.automatic)
            .onChange(of: model.selection) {
                guard let id = model.selectedResult?.id else { return }
                proxy.scrollTo(id)
            }
        }
    }
}

/// A large icon and the dates of the selected file or folder.
private struct PreviewPane: View {
    let result: LaunchResult?

    var body: some View {
        if let result, let url = result.url {
            let dates = Self.dates(url)
            VStack(spacing: Space.lg) {
                Spacer(minLength: 0)
                IconCache.image(for: result.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: LauncherLayout.previewIconSize, height: LauncherLayout.previewIconSize)
                Spacer(minLength: 0)
                Grid(alignment: .leading, horizontalSpacing: Space.sm, verticalSpacing: Space.xs) {
                    if let created = dates.created { row("Created", created) }
                    if let modified = dates.modified { row("Modified", modified) }
                }
                .font(.callout)
            }
            .padding(.bottom, Space.sm)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Preview, " + [dates.created.map { "Created \($0)" }, dates.modified.map { "Modified \($0)" }]
                .compactMap { $0 }.joined(separator: ", "))
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value)
        }
    }

    private static func dates(_ url: URL) -> (created: String?, modified: String?) {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened)
        return (values?.creationDate?.formatted(style), values?.contentModificationDate?.formatted(style))
    }
}
