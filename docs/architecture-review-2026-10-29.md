# Architecture review 2026-10-29 (end of M2)

M2 added browsing, the action panel, the selection hotkey, Quick Look, the buffer and the search settings. 5,335 lines of Swift across 40 files. No file in the app passes 400 lines except the self-test. The result-source seam from the last review held up: S-014 changed `FileSearch` and `QueryKind` and no other source.

## One self-test file per milestone section  [Strong]

Files: Sources/Reach/SelfTest.swift (750 lines; `checkLauncher` alone is 345)
Signal: a Swift file over 600 lines; the last review said to split it at 400. It changed in 17 of the last 30 days' commits, more than any other file.
Problem: every story appends to the same file, so each story's diff and each merge touch it. Finding the checks for one story means scrolling past the others. Example: S-014's checks sit below 560 lines of Quick Look and buffer setup.
Proposal: `Sources/Reach/SelfTest/` with the runner and `check` in `SelfTest.swift`, and one `extension SelfTest` file per section:

```swift
// SelfTest/SelfTest+Launcher.swift   S-001 to S-011
// SelfTest/SelfTest+QuickLook.swift  S-012
// SelfTest/SelfTest+Buffer.swift     S-013
// SelfTest/SelfTest+Search.swift     S-014
// SelfTest/FakeSource.swift
extension SelfTest {
    static func checkSearch(model: AppModel) async { ... }
}
```

Benefits: locality, since a story adds one file and leaves the others alone. M3 adds sections without growing one file.
Proof of same behavior: the list of check names and PASS/FAIL lines from `tools/selftest.sh`, before and after, must be identical (126 checks).
Plan: one commit that moves code without changing it (the checks keep their order).

## Saved settings behind one store  [Worth exploring]

Files: Launcher/ActionSettings.swift, Launcher/PreviewSettings.swift, Launcher/SearchSettings.swift, Models.swift
Signal: the same pattern three times (`Store.isOverridden` in 12 places); M3 adds settings for the calculator, web searches and the clipboard.
Problem: each settings type writes its own load, save and test-run guard. The self-test changes the shared singletons and must remember to reset them (S-014's `reset()`).
Proposal: one `SettingsStore` with a UserDefaults adapter and an in-memory adapter for test and snapshot runs, handed to each settings type:

```swift
protocol SettingsStore {
    func value<T: Codable>(_ key: String) -> T?
    func set<T: Codable>(_ value: T, _ key: String)
}
```

Benefits: one place decides "never touch the real settings in a test". New settings are a few lines each.
Proof of same behavior: the saved UserDefaults keys and their values are the same before and after, and the self-test passes.
Plan: the store and both adapters; then move one settings type per commit.

## Quick Look's keyboard handover in one place  [Worth exploring]

Files: Launcher/QuickLook.swift, Launcher/LauncherPanel.swift
Signal: 4 FIXLOG entries in the same area (S-012, S-013), plus a test that fails now and then (Quick Look closing while its animation is still running).
Problem: the rule "the launcher keeps the keyboard while Quick Look moves it" is split between `QuickLook.isMovingKeyboard` and the `onResign` handler in `LauncherController`, and it reads the system clock, so no unit test can cover the timing.
Proposal: `QuickLook.keepsLauncherKey(keyWindow: NSWindow?, now: TimeInterval) -> Bool`, with the 1 s grace and the QLPreviewPanel check inside, and the clock passed in.
Benefits: the timing rules get unit tests. `onResign` becomes one line.
Proof of same behavior: the Quick Look self-test checks, including the real ⇧ CGEvent checks.
Plan: one commit. It does not fix the flaky test. That needs its own investigation.

## LauncherModel growth  [Speculative]

Files: Launcher/LauncherModel.swift (360 lines, 12 commits in 30 days)
Signal: close to the 400-line threshold for a type.
Problem: none yet. Buffer and action-panel orchestration live next to the query and the results.
Proposal: when M3 pushes it past 400 lines, move the action-panel and buffer functions into an extension file. `FileBuffer` already holds the logic.

## Top recommendation

**One self-test file per milestone section.** It is Strong: a move with no logic change, a proof you can check by diffing the output, and every M3 story gets a file of its own.

## Considered, not recommended

- A protocol around `NSMetadataQuery` for `FileSearch`: `SpotlightPredicate` is already pure and unit-tested. The self-test uses real Spotlight on purpose.
- Splitting `LauncherPanel`'s key handling into a keymap type: 251 lines that read clearly. Revisit when M3 adds keys.
- Moving `FileQuery.swift` (190 lines) into several files: one topic, and it is pure and tested.

## Outcome

Done on 2026-10-29 in two commits, as the user chose (the self-test split and the Quick Look rule):

- The self-test split into `Sources/Reach/SelfTest/` (b7bf36f). Two runs gave PASS lines identical to the run before the move. A third run failed only "file search answers within 200 ms" (786 and 453 ms) while the Mac was busy right after the full snapshot run; HEAD passed at that moment and the split passed twice after. A timing check, not the move.
- `KeyboardHandover` in ReachKit holds Quick Look's keyboard rule with the clock passed in, with 3 unit tests (51 in all). `onResign` is one condition. Two self-test runs identical to the baseline, including the real ⇧ events. The flaky mid-animation check is not touched by this.

Left for later: "Saved settings behind one store" and "LauncherModel growth".
