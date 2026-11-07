import ReachKit
import SwiftUI

/// Settings > Web Bookmarks (S-057): Safari and Chrome, where bookmarks show,
/// and which browser opens them. Without Full Disk Access, Safari is skipped
/// and this page says so, with a button to the Full Disk Access pane.
struct BookmarkSettingsView: View {
    @Bindable private var settings = BookmarkSettings.shared
    private let source = AppModel.shared.launcherModel.bookmarks

    var body: some View {
        Section {
            Toggle(isOn: $settings.safariOn) {
                Text("Safari")
                Text(safariText)
            }
            .toggleStyle(.checkbox)
            if Self.showsAccessRow(settings: settings, source: source) {
                LabeledContent {
                    Button("Open Full Disk Access…", action: Self.openFullDiskAccess)
                } label: {
                    Label {
                        Text("Full Disk Access")
                        Text("macOS keeps Safari’s bookmarks private. Turn on Reach under Full Disk Access; until then Safari is skipped.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                    }
                }
            }
            Toggle(isOn: $settings.chromeOn) {
                Text("Google Chrome")
                Text(count(.chrome, none: "No Chrome bookmarks found.", suffix: ", from every profile."))
            }
            .toggleStyle(.checkbox)
        } header: {
            Text("Sources")
        } footer: {
            Text("A bookmark in both browsers shows once. Reach reads the bookmarks again after you change them, the next time you search.")
                .foregroundStyle(.secondary)
        }
        Section {
            Picker("Show bookmarks", selection: $settings.showMode) {
                ForEach(BookmarkShowMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Open in", selection: $settings.openMode) {
                ForEach(BookmarkOpenMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        } header: {
            Text("Results")
        } footer: {
            Text("Type “\(WebBookmarks.keyword)” and a space to search only bookmarks, like “\(WebBookmarks.keyword) swift”. With Keyword Only, other searches leave bookmarks out.")
                .foregroundStyle(.secondary)
        }
        .onAppear { if settings.safariOn || settings.chromeOn { source.read() } }
        .onChange(of: settings.safariOn) { source.read() }
        .onChange(of: settings.chromeOn) { source.read() }
    }

    /// The Full Disk Access row shows while Safari is on and macOS refused its file.
    static func showsAccessRow(settings: BookmarkSettings, source: BookmarkSource) -> Bool {
        settings.safariOn && source.safariAccess == .denied
    }

    /// Open Full Disk Access…: through the launcher's opener, so the self-test can record it.
    static func openFullDiskAccess() {
        if let url = BookmarkSource.fullDiskAccess { _ = AppModel.shared.launcherModel.opener(url) }
    }

    private var safariText: String {
        switch source.safariAccess {
        case .denied: "Needs Full Disk Access."
        case .missing: "No Safari bookmarks found."
        default: count(.safari, none: "Favorites and the Bookmarks Menu.", suffix: ", from Favorites and the Bookmarks Menu.")
        }
    }

    private func count(_ browser: BookmarkBrowser, none: String, suffix: String) -> String {
        guard let count = source.counts[browser], count > 0 else { return none }
        return "\(count) bookmark\(count == 1 ? "" : "s")\(suffix)"
    }
}
