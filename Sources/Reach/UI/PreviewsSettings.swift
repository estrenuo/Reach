import AppKit
import ReachKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings > Previews: Quick Look on ⇧, and the file types and folders it skips (S-012).
struct PreviewsSettings: View {
    @Bindable private var settings = PreviewSettings.shared

    var body: some View {
        Section("Quick Look") {
            Toggle(isOn: $settings.quickLook) {
                Text("Tap ⇧ to Quick Look the selected result")
                Text("Or press ⌘Y. Press it again or Esc to close Quick Look.")
            }
        }
        SkipList(title: "Skip These File Types", empty: "No file types",
                 footer: "Files of these types get no Quick Look and show no dates in the Preview. Drop a file here or click + to choose one.",
                 addHelp: "Add a file type to skip",
                 items: $settings.skips.types, label: Self.typeLabel, add: Self.chooseType, dropped: Self.type(of:))
        SkipList(title: "Skip These Folders", empty: "No folders",
                 footer: "Nothing inside these folders gets Quick Look or Preview dates. Useful for slow network drives.",
                 addHelp: "Add a folder to skip",
                 items: $settings.skips.folders, label: Self.folderLabel, add: Self.chooseFolder, dropped: Self.folder(of:))
    }

    private static func typeLabel(_ id: String) -> (String, String) {
        (UTType(id)?.localizedDescription?.capitalizedFirst ?? id, id)
    }

    private static func folderLabel(_ path: String) -> (String, String) {
        (FileManager.default.displayName(atPath: path), (path as NSString).abbreviatingWithTildeInPath)
    }

    private static func type(of url: URL) -> String? {
        (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.identifier
    }

    private static func folder(of url: URL) -> String? {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true ? realPath(url) : nil
    }

    /// Results carry the real path, like /private/tmp for /tmp, so skipped folders do too.
    private static func realPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().path
    }

    private static func chooseType() -> String? {
        let open = NSOpenPanel()
        open.message = "Choose a file of the type to skip."
        open.prompt = "Skip Type"
        return open.runModal() == .OK ? open.url.flatMap(type(of:)) : nil
    }

    private static func chooseFolder() -> String? {
        let open = NSOpenPanel()
        open.canChooseFiles = false
        open.canChooseDirectories = true
        open.message = "Choose a folder to skip."
        open.prompt = "Skip Folder"
        return open.runModal() == .OK ? open.url.map(realPath) : nil
    }
}

/// One list of skipped things, with + and − under it, like the lists in System Settings.
private struct SkipList: View {
    let title: String
    let empty: String
    let footer: String
    let addHelp: String
    @Binding var items: [String]
    let label: (String) -> (String, String)
    let add: () -> String?
    let dropped: (URL) -> String?
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
                .disabled(selected == nil)
                .help("Stop skipping the selected item")
                .accessibilityLabel("Stop skipping the selected item")
                Spacer()
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

private extension String {
    /// "PNG image" from "PNG image", "Plain text document" from "plain text document".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
