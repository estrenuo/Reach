import AppKit
import ReachKit

/// Asks the front browser for its tab's URL (S-054). macOS asks once whether
/// Reach may control the browser; when that is off, the problem says where to allow it.
enum CurrentTabReader {
    static func read() -> Result<String?, WorkflowProblem> {
        let workspace = NSWorkspace.shared
        let running = workspace.runningApplications.compactMap(\.bundleIdentifier)
        guard let browser = CurrentTab.browser(front: workspace.frontmostApplication?.bundleIdentifier, running: running),
              let source = CurrentTab.script(for: browser) else { return .success(nil) }
        var error: NSDictionary?
        let answer = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            let name = workspace.urlForApplication(withBundleIdentifier: browser).map { FileManager.default.displayName(atPath: $0.path) }
                ?? browser
            // -1743: people said no to Reach controlling the browser.
            if error[NSAppleScript.errorNumber] as? Int == -1743 {
                return .failure(.init(kind: "Allow Reach to control \(name) in System Settings > Privacy & Security > Automation."))
            }
            return .success(nil)
        }
        return .success(answer?.stringValue)
    }
}
