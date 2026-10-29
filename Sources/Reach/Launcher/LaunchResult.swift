import AppKit
import SwiftUI

/// One result in the launcher. Built on the fly for every query, never stored.
struct LaunchResult: Identifiable, Equatable {
    enum Icon: Equatable {
        case file(String)
        case symbol(String)
    }

    /// A stable id across queries: the path for apps and files, the engine for fallbacks.
    var id: String
    var title: String
    var subtitle: String
    var icon: Icon
    /// What Return opens. Nil for hint rows like "Type a file name".
    var url: URL?
    /// Spoken by VoiceOver before the title, like "PDF document".
    var kindLabel: String = ""
    /// A folder you can browse into with → (not a package like an app).
    var isFolder = false
    /// Return reveals it in Finder instead of opening it (the `find` keyword, S-014).
    var reveals = false
    /// The text Return copies, for a calculation (S-015). It has no URL.
    var answer: String?
    /// The query Return puts in the search field: "wik" becomes "wiki " (S-016).
    var completes: String?
    /// Shown above the ranked results: a calculation's answer, a typed URL.
    var isPinned = false
    /// Opening it adds its URL to the URL history (S-017).
    var remembers = false

    var isOpenable: Bool { url != nil || answer != nil || completes != nil }
}

/// File icons from the workspace, cached per path.
enum IconCache {
    private static var cache: [String: NSImage] = [:]

    static func image(for icon: LaunchResult.Icon) -> Image {
        switch icon {
        case .symbol(let name):
            return Image(systemName: name)
        case .file(let path):
            if let cached = cache[path] { return Image(nsImage: cached) }
            let image = NSWorkspace.shared.icon(forFile: path)
            cache[path] = image
            return Image(nsImage: image)
        }
    }
}
