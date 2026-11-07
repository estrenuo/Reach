import AppKit
import CoreServices
import ReachKit

/// Whether macOS lets Reach send Apple Events to Music (Automation).
enum MusicAccess: Equatable {
    case allowed
    case denied
    /// Not asked yet, or Music is not running, so macOS cannot tell.
    case unknown
}

/// What came of sending a command to Music.
enum MusicOutcome: Equatable {
    case sent
    case denied
    case failed
}

/// The seam between Reach and Music.app (S-059). The live player talks to
/// Music through Apple Events; the self-test and snapshots swap in fakes, so
/// a test run never sends an event or triggers the Automation prompt.
struct MusicPlayer {
    var send: @MainActor (MusicRequest) -> MusicOutcome
    var nowPlaying: @MainActor () -> MusicTrack?
    var access: @MainActor () -> MusicAccess

    static let bundleID = "com.apple.Music"
    static let app = "/System/Applications/Music.app"
    static let automationSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    static let allowText = "Allow Reach to control Music in System Settings > Privacy & Security > Automation"

    /// Sends nothing and knows no track: what test runs start with.
    static let silent = MusicPlayer(send: { _ in .sent }, nowPlaying: { nil }, access: { .unknown })

    static var live: MusicPlayer {
        let tracker = NowPlaying.shared
        return MusicPlayer(send: { run($0) }, nowPlaying: { tracker.current() }, access: { checkAccess() })
    }

    /// Runs the request's AppleScript. Error -1743: people said no to Reach controlling Music.
    private static func run(_ request: MusicRequest) -> MusicOutcome {
        var error: NSDictionary?
        NSAppleScript(source: request.script)?.executeAndReturnError(&error)
        guard let error else { return .sent }
        return error[NSAppleScript.errorNumber] as? Int == -1743 ? .denied : .failed
    }

    /// Asks macOS without showing the prompt. Music must be running for an answer.
    static func checkAccess() -> MusicAccess {
        guard isRunning else { return .unknown }
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let desc = target.aeDesc else { return .unknown }
        switch AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, false) {
        case noErr: return .allowed
        case OSStatus(errAEEventNotPermitted): return .denied
        default: return .unknown
        }
    }

    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}

/// The song Music is playing, from the notification Music posts on every
/// change, so typing `next` never waits for an Apple Event. When Reach starts
/// after Music, it asks Music once, and only when Automation is already allowed.
final class NowPlaying {
    static let shared = NowPlaying()
    private var track: MusicTrack?
    private var known = false
    private var observer: NSObjectProtocol?

    private init() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main) { note in
            let info = note.userInfo ?? [:]
            let state = info["Player State"] as? String
            let name = info["Name"] as? String ?? ""
            let artist = info["Artist"] as? String ?? ""
            MainActor.assumeIsolated {
                NowPlaying.shared.known = true
                NowPlaying.shared.track = state == "Stopped" || name.isEmpty ? nil : MusicTrack(name: name, artist: artist)
            }
        }
    }

    func current() -> MusicTrack? {
        guard MusicPlayer.isRunning else {
            known = false
            track = nil
            return nil
        }
        if !known, MusicPlayer.checkAccess() == .allowed {
            known = true
            track = Self.ask()
        }
        return track
    }

    private static func ask() -> MusicTrack? {
        let source = """
            tell application "Music"
                if player state is stopped then return ""
                return (name of current track) & tab & (artist of current track)
            end tell
            """
        var error: NSDictionary?
        guard let answer = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue, error == nil else { return nil }
        let parts = answer.components(separatedBy: "\t")
        guard let name = parts.first, !name.isEmpty else { return nil }
        return MusicTrack(name: name, artist: parts.count > 1 ? parts[1] : "")
    }
}
