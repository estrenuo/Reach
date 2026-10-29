import AppKit
import ReachKit
import SwiftUI

/// The chosen launcher theme (S-032), saved in `Store.settings`. The launcher
/// and the preview in Settings > Appearance read it, so a pick shows at once.
@Observable
final class LauncherThemeStore {
    static let shared = LauncherThemeStore()

    var themeID: String { didSet { Store.settings.set(themeID, forKey: "appearance.theme") } }
    /// The preview sits on the desktop picture instead of a plain background.
    var previewOnDesktop: Bool { didSet { Store.settings.set(previewOnDesktop, forKey: "appearance.previewOnDesktop") } }

    var theme: LauncherTheme { LauncherTheme.named(themeID) }

    private init() {
        themeID = Store.settings.string(forKey: "appearance.theme") ?? LauncherTheme.standard.id
        previewOnDesktop = Store.settings.object(forKey: "appearance.previewOnDesktop") as? Bool ?? true
    }

    /// Back to the standard theme; the self-test leaves no trace this way.
    func reset() {
        themeID = LauncherTheme.standard.id
        previewOnDesktop = true
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

extension View {
    /// The launcher's background in a theme's surface, for the bar and its previews.
    func launcherSurface(_ surface: LauncherTheme.Surface, cornerRadius: CGFloat) -> some View {
        modifier(LauncherSurface(surface: surface, cornerRadius: cornerRadius))
    }
}

private struct LauncherSurface: ViewModifier {
    let surface: LauncherTheme.Surface
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch surface {
        case .glass:
            content.glassEffect(.regular, in: shape)
        case .clearGlass:
            content.glassEffect(.clear, in: shape)
        case .solid:
            content
                .background(Color(nsColor: .windowBackgroundColor), in: shape)
                .overlay(shape.strokeBorder(.separator, lineWidth: 1))
        }
    }
}
