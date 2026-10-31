import Foundation

/// The Automation Task "Current Tab of Frontmost Browser" (S-054): the URL of
/// the front tab, from Safari or a Chromium browser, through Apple Events.
public enum CurrentTab {
    public static let taskSuffix = "frontmost.tabs.current"

    /// Browsers Reach can ask, by bundle ID, in the order it looks for a running one.
    public static let browsers = ["com.apple.Safari", "com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac",
                                  "com.vivaldi.Vivaldi", "company.thebrowser.Browser", "org.chromium.Chromium"]

    /// The AppleScript that returns the front tab's URL in `bundleID`; nil for another app.
    public static func script(for bundleID: String) -> String? {
        guard browsers.contains(bundleID) else { return nil }
        let tab = bundleID == "com.apple.Safari" ? "URL of front document" : "URL of active tab of front window"
        return "tell application id \"\(bundleID)\" to return \(tab)"
    }

    /// The browser to ask: the app in front when it is one, else the first running one.
    public static func browser(front: String?, running: [String]) -> String? {
        if let front, browsers.contains(front) { return front }
        return browsers.first(where: running.contains)
    }
}
