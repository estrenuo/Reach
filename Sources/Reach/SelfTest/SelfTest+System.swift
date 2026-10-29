import AppKit
import ReachKit

extension SelfTest {
    /// S-019: commands rank among apps, Confirm shows a row first, Esc goes
    /// back, and Eject lists disks. Every run goes to a recorder.
    static func checkSystem(model: AppModel) async {
        guard let launcher = model.launcher else { return }
        let lm = model.launcherModel
        let settings = SystemSettings.shared
        var ran: [SystemRun] = []
        lm.runSystem = { ran.append($0); return true }
        lm.system.disks = { [Disk(name: "Backup", url: URL(fileURLWithPath: "/Volumes/Backup")),
                             Disk(name: "USB Stick", url: URL(fileURLWithPath: "/Volumes/USB Stick"))] }
        defer {
            settings.reset()
            lm.runSystem = { _ in true }
            lm.system.disks = { Disk.ejectable() }
        }

        launcher.show()
        lm.query = "sleep"
        check("sleep offers Sleep and Sleep Displays", lm.results.first?.id == "system:sleep"
              && lm.results.contains { $0.id == "system:sleepDisplays" }, lm.results.map(\.title).joined(separator: ", "))
        lm.openSelected()
        check("a command without Confirm runs at once and hides the launcher",
              ran.map(\.command) == [.sleep] && !launcher.isVisible)

        launcher.show()
        lm.query = "restart"
        lm.openSelected()
        check("Confirm shows one row that asks first", ran.count == 1 && lm.results.count == 1
              && lm.results.first?.title == "Restart your Mac?" && lm.results.first?.subtitle == "↩ restarts, esc cancels"
              && launcher.isVisible, lm.results.map(\.title).joined(separator: ", "))
        lm.cancel()
        check("Esc on the confirmation goes back to the results", lm.query == "restart"
              && lm.results.first?.id == "system:restart" && ran.count == 1 && launcher.isVisible)
        lm.openSelected()
        lm.openSelected()
        check("↩ on the confirmation runs the command", ran.last?.command == .restart && ran.count == 2 && !launcher.isVisible)

        launcher.show()
        lm.query = "restart"
        lm.openSelected()
        lm.query = "restar"
        check("typing leaves the confirmation", lm.confirming == nil && lm.results.first?.id == "system:restart")

        settings[.restart].confirms = false
        lm.query = "restart "
        lm.openSelected()
        check("with Confirm off, restart runs at once", ran.last?.command == .restart && ran.count == 3)

        launcher.show()
        settings[.lock].isOn = false
        lm.query = "lock"
        check("a command that is off is not offered", !lm.results.contains { $0.id == "system:lock" })
        settings[.lock].keyword = "zzlock"
        settings[.lock].isOn = true
        lm.query = "zzlock"
        check("a changed keyword finds the command", lm.results.first?.id == "system:lock")

        lm.query = "eject"
        check("eject lists each disk", lm.results.filter { $0.system?.command == .eject }.map(\.title)
              == ["Eject “Backup”", "Eject “USB Stick”"], lm.results.map(\.title).joined(separator: ", "))
        lm.query = "eject us"
        check("words after eject pick the disk", lm.results.first?.title == "Eject “USB Stick”")
        lm.openSelected()
        check("↩ ejects that disk", ran.last?.disk?.path == "/Volumes/USB Stick")
        launcher.show()
        lm.system.disks = { [] }
        lm.query = "eject"
        check("without disks eject says so", lm.results.first?.title == SystemSource.noDisks
              && !lm.results.contains { $0.id == "system:ejectAll" })

        lm.runSystem = { _ in false }
        lm.query = "mute"
        lm.openSelected()
        check("a command that fails says so under its row", lm.errors["system:mute"] == "Unable to run “Toggle Mute”."
              && launcher.isVisible)
        launcher.hide()
    }
}
