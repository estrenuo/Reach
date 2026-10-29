import AppKit
import SwiftData
import SwiftUI

// Reach
//   Reach                      the app
//   APP_STORE=<file> Reach     use another database (tests, experiments)
//   APP_SNAPSHOT=<dir> Reach   save a PNG of every sidebar page and Settings tab in light and dark mode, then quit
//   APP_SEED=1 Reach           fill an empty /tmp store with sample snippets (tools/snap.sh)
//   Reach --selftest           run the self-test on a /tmp store and quit with 0 or 1 (tools/selftest.sh)
//   APP_ACCENT=<id> Reach      run with another accent from Theme.all (UI/Theme.swift)
//   APP_GRID=1 Reach           draw the 8 pt grid and the layout probes over the window

@main
struct ReachApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel.shared

    var body: some Scene {
        // Reach is an agent app: the launcher and the menu bar icon are the way in.
        // This window (snippets, M4) only opens for snapshots and the self-test.
        Window("Reach", id: "main") {
            ContentView()
                .environment(model)
                .themed()
                .overlay { if GridOverlay.enabled { GridOverlay() } }
                .frame(minWidth: 760, minHeight: 480)
        }
        .modelContainer(model.container)
        .defaultSize(width: 1100, height: 720)
        .defaultLaunchBehavior(AppModel.isTestRun ? .presented : .suppressed)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Snippet") { model.addSnippet() }
                    .keyboardShortcut("n")
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .themed()
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Reach", systemImage: "magnifyingglass") {
            StatusMenu()
        }
    }
}

/// The menu bar icon's menu.
struct StatusMenu: View {
    @Environment(\.openSettings) private var openSettings
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

    var body: some View {
        Button("Show Launcher") { AppModel.shared.launcher?.show() }
        Button("Version \(version)") {}
            .disabled(true)
        Divider()
        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppModel.isTestRun {
            // Snapshots and the self-test need a normal app with a front window.
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
        }
        AppModel.shared.startLauncher()
    }

    /// Closing a window never quits: the launcher keeps running.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// The self-test's result becomes the exit code, after a normal quit.
    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}

/// Where the data lives: ~/Library/Application Support/Reach/Reach.store
enum Store {
    /// True when APP_STORE points somewhere else (tests, snapshots, seed data).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    /// Where settings are saved: the app's own UserDefaults, or for test,
    /// snapshot and seed runs a separate suite that starts empty at every
    /// launch. Those runs never read or write the real settings this way.
    static let settings: UserDefaults = {
        guard isOverridden else { return .standard }
        let name = "com.sanderrobijns.reach.testrun"
        UserDefaults.standard.removePersistentDomain(forName: name)
        return UserDefaults(suiteName: name) ?? .standard
    }()

    static var url: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        let dir = URL.applicationSupportDirectory.appending(path: "Reach", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "Reach.store")
    }

    static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: Snippet.self, LearningEntry.self, URLVisit.self, configurations: ModelConfiguration(url: url))
        } catch {
            fatalError("Could not open the database at \(url.path): \(error)")
        }
    }
}
