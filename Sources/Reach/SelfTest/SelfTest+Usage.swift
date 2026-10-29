import Foundation
import ReachKit

extension SelfTest {
    /// S-040: each kind of use is counted for today, and the page has a summary and 28 days.
    static func checkUsage(model: AppModel) {
        let usage = UsageStore.shared
        let saved = usage.log
        defer { usage.replace(with: saved) }
        usage.replace(with: UsageLog())
        check("Usage starts with nothing counted", usage.summary().hasPrefix("Nothing counted yet"), usage.summary())

        let lm = model.launcherModel
        lm.onOpened("safari", LaunchResult(id: "selftest:usage", title: "Safari", subtitle: "", icon: .symbol("safari"), url: nil))
        lm.onUsed(.clipboard)
        lm.onUsed(.expansion)
        lm.onUsed(.expansion)
        let today = Date.now
        check("an opened result counts as Launcher", usage.log.count(.launcher, on: today) == 1)
        check("clips and expansions count on their own", usage.log.count(.clipboard, on: today) == 1
              && usage.log.count(.expansion, on: today) == 2)
        check("the summary gives the total", usage.summary().contains("4 uses"), usage.summary())
        check("the chart shows 28 days ending today", usage.log.chart(ending: today).count == 28
              && usage.log.chart(ending: today).last?.total == 4)
        check("Copy Stats has a line per day", usage.statsText().split(separator: "\n").count == 1 + 1 + 28)
        check("Usage is a Settings page", SettingsTab.pages.contains(.usage))
    }
}
