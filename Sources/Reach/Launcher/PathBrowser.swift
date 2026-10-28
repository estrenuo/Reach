import Foundation
import ReachKit

/// Lists a folder for a path query (`~/` or `/`), A to Z, filtered by the
/// typed name. The launcher keeps this order: no ranking, no fallbacks.
final class PathBrowser: ResultSource {
    /// Enough for any folder people browse; the list scrolls.
    static let limit = 500
    let home: String

    init(home: String = NSHomeDirectory()) {
        self.home = home
    }

    func results(for query: QueryKind, later: @escaping @MainActor ([Scored]) -> Void) -> [Scored]? {
        guard case .path(let path) = query else { return [] }
        let folder = URL(fileURLWithPath: path.expandedFolder(home: home), isDirectory: true)
        let shown = String(path.folder.dropLast()).isEmpty ? "/" : String(path.folder.dropLast())
        let options: FileManager.DirectoryEnumerationOptions = path.name.hasPrefix(".") ? [] : [.skipsHiddenFiles]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .localizedTypeDescriptionKey],
            options: options)
        else { return [hint("No folder at “\(shown)”", symbol: "questionmark.folder")] }

        let name = folder.lastPathComponent.isEmpty ? "/" : folder.lastPathComponent
        var entries = urls.map { (url: $0, title: $0.lastPathComponent, score: 0) }
        if path.name.isEmpty {
            entries.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        } else {
            entries = entries.compactMap { entry in
                Matcher.score(query: path.name, title: entry.title).map { (entry.url, entry.title, $0) }
            }
            // Best match first; equal matches A to Z.
            entries.sort { $0.score != $1.score ? $0.score > $1.score
                : $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
        if entries.isEmpty {
            return [path.name.isEmpty ? hint("“\(name)” is empty", symbol: "folder")
                                      : hint("Nothing in “\(name)” matches “\(path.name)”", symbol: "questionmark.folder")]
        }
        return entries.prefix(Self.limit).map { entry in
            Scored(result: Self.result(entry.url, title: entry.title), score: entry.score)
        }
    }

    private static func result(_ url: URL, title: String) -> LaunchResult {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .localizedTypeDescriptionKey])
        let isFolder = values?.isDirectory == true && values?.isPackage != true
        return LaunchResult(
            id: url.path, title: title, subtitle: "", icon: .file(url.path),
            url: url, kindLabel: isFolder ? "Folder" : values?.localizedTypeDescription ?? "File",
            isFolder: isFolder)
    }

    private func hint(_ title: String, symbol: String) -> Scored {
        Scored(result: LaunchResult(id: "hint:path", title: title, subtitle: "", icon: .symbol(symbol), url: nil),
               score: 0)
    }
}
