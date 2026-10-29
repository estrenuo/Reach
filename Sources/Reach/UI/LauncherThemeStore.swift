import AppKit
import ReachKit
import SwiftUI

/// The chosen launcher theme (S-032) and the own themes (S-033), saved in
/// `Store.settings`. The launcher and the preview in Settings > Appearance
/// read it, so a pick or a change shows at once.
@Observable
final class LauncherThemeStore {
    static let shared = LauncherThemeStore()

    var themeID: String { didSet { Store.settings.set(themeID, forKey: "appearance.theme") } }
    /// Own themes, in the order they were made. Built-in ones are never in here.
    private(set) var own: [LauncherTheme] { didSet { saveOwn() } }
    /// The part of the preview whose editor is open. Not saved.
    var editing: LauncherTheme.Part?
    /// The preview sits on the desktop picture instead of a plain background.
    var previewOnDesktop: Bool { didSet { Store.settings.set(previewOnDesktop, forKey: "appearance.previewOnDesktop") } }

    var theme: LauncherTheme { LauncherTheme.named(themeID, in: own) }
    var all: [LauncherTheme] { LauncherTheme.all + own }

    private init() {
        themeID = Store.settings.string(forKey: "appearance.theme") ?? LauncherTheme.standard.id
        own = Store.settings.data(forKey: "appearance.ownThemes")
            .flatMap { try? JSONDecoder().decode([LauncherTheme].self, from: $0) } ?? []
        previewOnDesktop = Store.settings.object(forKey: "appearance.previewOnDesktop") as? Bool ?? true
    }

    /// Back to the standard theme; the self-test leaves no trace this way.
    func reset() {
        themeID = LauncherTheme.standard.id
        previewOnDesktop = true
        own = []
    }

    /// An own copy of `theme`, picked at once so the next click edits it.
    @discardableResult
    func duplicate(_ theme: LauncherTheme) -> LauncherTheme {
        let copy = theme.duplicate(id: UUID().uuidString, taken: all.map(\.name))
        own.append(copy)
        themeID = copy.id
        return copy
    }

    /// Saves a change to an own theme. Built-in themes stay as they are.
    func update(_ theme: LauncherTheme) {
        guard let index = own.firstIndex(where: { $0.id == theme.id }) else { return }
        own[index] = theme.clamped()
    }

    /// Takes an own theme out and says where it was, for Undo. A deleted
    /// theme that was picked leaves Reach picked.
    func delete(_ id: String) -> (theme: LauncherTheme, index: Int, wasPicked: Bool)? {
        guard let index = own.firstIndex(where: { $0.id == id }) else { return nil }
        let wasPicked = themeID == id
        let theme = own.remove(at: index)
        if wasPicked { themeID = LauncherTheme.standard.id }
        return (theme, index, wasPicked)
    }

    func restore(_ theme: LauncherTheme, at index: Int, pick: Bool) {
        own.insert(theme, at: min(index, own.count))
        if pick { themeID = theme.id }
    }

    private func saveOwn() {
        Store.settings.set(try? JSONEncoder().encode(own), forKey: "appearance.ownThemes")
    }

    /// What the preview in Settings sits on: the desktop picture, or nothing.
    func previewPicture() -> NSImage? {
        previewOnDesktop ? Self.desktopPicture() : nil
    }

    /// The desktop picture behind the preview. Snapshots and the self-test
    /// draw a sample instead: snapshots get shared, the picture is the person's own.
    static func desktopPicture() -> NSImage? {
        if AppModel.isTestRun { return sampleDesktop }
        guard let screen = NSScreen.main, let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        return NSImage(contentsOf: url)
    }

    /// The thumbnails always sit on the sample, so every theme is shown on the same ground.
    static var sampleThumbnail: NSImage { sampleDesktop }

    private static let sampleDesktop = NSImage(size: NSSize(width: 640, height: 400), flipped: false) { rect in
        NSGradient(colors: [NSColor(hex: 0xF97316), NSColor(hex: 0xE84A93), NSColor(hex: 0x5E6AD2), NSColor(hex: 0x2BC48A)])?
            .draw(in: rect, angle: 35)
        return true
    }
}

extension LauncherTheme.Mode {
    /// For an AppKit window: nil follows the Mac.
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// For a SwiftUI view: nil follows the window.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
