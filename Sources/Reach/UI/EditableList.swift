import SwiftUI

/// A list of file types or folders with + and − under it, like the lists in
/// System Settings: what Previews skips, and the search scope.
struct EditableList: View {
    let title: String
    let empty: String
    let footer: String
    let addHelp: String
    let removeHelp: String
    @Binding var items: [String]
    let label: (String) -> (String, String)
    let add: () -> String?
    let dropped: (URL) -> String?
    /// − is off at this many items: the search scope keeps one folder.
    var minimum = 0
    /// Shows Reset at the right, with this tooltip.
    var resetHelp: String?
    var reset: () -> Void = {}
    @State private var selected: String?

    var body: some View {
        Section {
            if items.isEmpty {
                Text(empty)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(items, id: \.self) { item in
                let (name, detail) = label(item)
                LabeledContent {
                    Text(detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(detail)
                } label: {
                    Text(name).lineLimit(1)
                }
                .contentShape(Rectangle())
                .listRowBackground(selected == item ? Color.accentColor.opacity(0.2) : nil)
                .onTapGesture { selected = item }
                .accessibilityAddTraits(selected == item ? .isSelected : [])
            }
            HStack(spacing: 0) {
                Button {
                    if let new = add() { insert(new) }
                } label: {
                    Image(systemName: "plus").frame(width: Space.xl, height: Space.xl)
                }
                .help(addHelp)
                .accessibilityLabel(addHelp)
                Button {
                    items.removeAll { $0 == selected }
                    selected = nil
                } label: {
                    Image(systemName: "minus").frame(width: Space.xl, height: Space.xl)
                }
                .disabled(selected == nil || items.count <= minimum)
                .help(removeHelp)
                .accessibilityLabel(removeHelp)
                Spacer()
                if let resetHelp {
                    Button("Reset") {
                        reset()
                        selected = nil
                    }
                    .help(resetHelp)
                }
            }
            .buttonStyle(.borderless)
        } header: {
            Text(title)
        } footer: {
            Text(footer).foregroundStyle(.secondary)
        }
        .dropDestination(for: URL.self) { urls, _ in
            let new = urls.compactMap(dropped)
            new.forEach(insert)
            return !new.isEmpty
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(items.isEmpty ? "\(title), empty" : title)
    }

    private func insert(_ item: String) {
        if !items.contains(item) { items.append(item) }
        selected = item
    }
}
