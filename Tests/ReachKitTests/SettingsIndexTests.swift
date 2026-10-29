import Foundation
import Testing
@testable import ReachKit

/// The Settings views, read as text: every fixed label in them.
private func settingsLabels() throws -> [(file: String, label: String)] {
    let sources = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../Sources/Reach").standardized
    let files = try FileManager.default.subpathsOfDirectory(atPath: sources.path)
        .filter { $0.hasSuffix(".swift") && !$0.hasPrefix("SelfTest") }
        .filter { $0.hasSuffix("SettingsView.swift") || $0.hasSuffix("Settings.swift") || $0.hasSuffix("HotkeyRecorder.swift")
            || $0.hasSuffix("LauncherOptionsSheet.swift") }
    // Labels, headings and pickers; Text and Button only when short, so footers and generic buttons stay out.
    let pattern = /\b(Section|Toggle|Picker|LabeledContent|Text|Button|EditableList)\((?:title: )?"((?:[^"\\]|\\.)*)"/
    let generic: Set<String> = ["Cancel", "Done", "Remove", "Move Up", "Move Down", "Delete", "Duplicate", "Rename", "Rename…",
                                "Reset", "Clear", "Clear…", "Filter", "Page", "Edit…", "Edit Fallbacks", "Open System Settings…",
                                "No custom searches", "Features", "Search Settings", "Always", "Never", "Selected Row Only",
                                "Mouse Screen", "Main Screen", "Active Screen",
                                // Sample values in text fields.
                                "ddg", "http", "https"]
    var labels: [(String, String)] = []
    for file in files {
        let text = try String(contentsOf: sources.appending(path: file), encoding: .utf8)
        for match in text.matches(of: pattern) {
            let (kind, label) = (String(match.1), String(match.2))
            if label.contains("\\(") || label.contains("{") || label.count < 3 || generic.contains(label) { continue }
            if ["Text", "Button"].contains(kind), label.count > 40 || label.hasSuffix(".") { continue }
            labels.append((file, label))
        }
    }
    return labels
}

@Test func everySettingsLabelIsIndexed() throws {
    let labels = try settingsLabels()
    #expect(labels.count > 60, "read \(labels.count) labels")
    let titles = Set(SettingsIndex.entries.map(\.title))
    for (file, label) in labels {
        #expect(titles.contains(label), "\(file): “\(label)” is not in SettingsIndex")
    }
}

@Test func searchFindsASettingByAnyWordOfItsLabel() {
    #expect(SettingsIndex.search("login").first?.title == "Open at login")
    #expect(SettingsIndex.search("menu bar").prefix(2).contains { $0.title == "Show menu bar icon" })
    #expect(SettingsIndex.search("MENU").contains { $0.title == "Show menu bar icon" })
    #expect(SettingsIndex.search("visible res").first?.page == "appearance")
}

@Test func searchUsesSectionsPagesAndExtraWords() {
    #expect(SettingsIndex.search("autostart").first?.title == "Open at login")
    #expect(SettingsIndex.search("volume").contains { $0.page == "system" })
    #expect(SettingsIndex.search("clip merg", pageTitles: ["clipboard": "Clipboard"]).prefix(2).contains { $0.title == "Merging" })
}

@Test func labelsThatStartWithTheQueryComeFirst() {
    let results = SettingsIndex.search("show")
    #expect(results.first.map { $0.title.lowercased().hasPrefix("show") } == true)
}

@Test func searchIgnoresCaseAccentsAndEmptyQueries() {
    #expect(SettingsIndex.search("").isEmpty)
    #expect(SettingsIndex.search("   ").isEmpty)
    #expect(SettingsIndex.search("ÁCCENT").first?.title == "Accent color")
    #expect(SettingsIndex.search("xyzzy").isEmpty)
}

@Test func everyEntryHasAPageAndIsUnique() {
    let pages: Set<String> = ["general", "search", "web", "system", "terminal", "dictionary", "contacts", "clipboard",
                              "snippets", "actions", "previews", "appearance", "advanced"]
    for entry in SettingsIndex.entries {
        #expect(pages.contains(entry.page), "\(entry.title) on \(entry.page)")
    }
}
