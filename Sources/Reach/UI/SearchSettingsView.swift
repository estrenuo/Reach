import AppKit
import ReachKit
import SwiftUI

/// Settings > Search (S-014): the file search keywords, what they leave out,
/// what a query without a keyword adds, and where Reach looks.
struct SearchSettingsView: View {
    @Bindable private var settings = SearchSettings.shared

    var body: some View {
        Section {
            ForEach(FileMode.allCases, id: \.self) { mode in
                KeywordRow(mode: mode, keywords: $settings.keywords)
            }
        } header: {
            Text("Keywords")
        } footer: {
            Text("Type a keyword and a space, then what you look for: “\(settings.keywords[.reveal].word) report” shows report.pdf in Finder. ' or a space at the start also opens files.")
                .foregroundStyle(.secondary)
        }
        Section {
            CheckboxGrid(cases: HiddenKind.allCases, title: \.title, selection: $settings.hidden)
        } header: {
            Text("Don't Show")
        } footer: {
            Text("The keywords leave these kinds of files out.")
                .foregroundStyle(.secondary)
        }
        Section {
            CheckboxGrid(cases: ResultType.allCases, title: \.title, selection: $settings.types)
        } header: {
            Text("Default Results")
        } footer: {
            Text("A query without a keyword shows apps, and files of the types you tick here. Each type makes the results a little slower.")
                .foregroundStyle(.secondary)
        }
        EditableList(title: "Search Scope", empty: "No folders",
                     footer: "Reach looks for apps and files in these folders. File search leaves out ~/Library, except iCloud Drive and cloud storage. Drop folders here from Finder.",
                     addHelp: "Add a folder to search", removeHelp: "Stop searching the selected folder",
                     items: $settings.scope, label: Self.folderLabel, add: Self.chooseFolder, dropped: Self.folder(of:),
                     minimum: 1, resetHelp: "Put back the standard folders",
                     reset: { settings.scope = SearchSettings.standardScope })
    }

    /// The path is the name: four folders are called Applications.
    private static func folderLabel(_ path: String) -> (String, String) {
        ((path as NSString).abbreviatingWithTildeInPath, "")
    }

    private static func folder(of url: URL) -> String? {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true ? url.path : nil
    }

    private static func chooseFolder() -> String? {
        let open = NSOpenPanel()
        open.canChooseFiles = false
        open.canChooseDirectories = true
        open.message = "Choose a folder to search."
        open.prompt = "Add Folder"
        return open.runModal() == .OK ? open.url?.path : nil
    }
}

/// One keyword: on or off, and its word. The word saves on Return or when the
/// field loses focus, and only when it is a valid keyword; Esc puts the saved word back.
private struct KeywordRow: View {
    let mode: FileMode
    @Binding var keywords: FileKeywords
    @State private var draft = ""
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Toggle(mode.title, isOn: $keywords[mode].isOn)
                .toggleStyle(.checkbox)
            Spacer()
            VStack(alignment: .trailing, spacing: Space.xs) {
                TextField("Keyword", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 120)
                    .focused($focused)
                    .disabled(!keywords[mode].isOn)
                    .onSubmit(save)
                    .onExitCommand(perform: revert)
                    .accessibilityLabel("Keyword for \(mode.title)")
                if let problem {
                    Text(problem)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear { draft = keywords[mode].word }
        .onChange(of: focused) { _, now in if !now { save() } }
    }

    private func save() {
        let word = draft.trimmingCharacters(in: .whitespaces).lowercased()
        problem = keywords.problem(with: word, for: mode)
        guard problem == nil else { return }
        draft = word
        keywords[mode].word = word
    }

    private func revert() {
        draft = keywords[mode].word
        problem = nil
    }
}

/// Checkboxes in three columns of one width, one per case, ticked when in
/// `selection`. The same width in every grid, so the sections line up.
private struct CheckboxGrid<Item: Hashable>: View {
    let cases: [Item]
    let title: KeyPath<Item, String>
    @Binding var selection: Set<Item>
    static var column: CGFloat { 136 }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Space.lg, verticalSpacing: Space.sm) {
            ForEach(Array(stride(from: 0, to: cases.count, by: 3)), id: \.self) { start in
                GridRow {
                    ForEach(cases[start..<min(start + 3, cases.count)], id: \.self) { item in
                        Toggle(item[keyPath: title], isOn: Binding(
                            get: { selection.contains(item) },
                            set: { on in if on { selection.insert(item) } else { selection.remove(item) } }))
                            .toggleStyle(.checkbox)
                            .frame(width: Self.column, alignment: .leading)
                    }
                }
            }
        }
    }
}
