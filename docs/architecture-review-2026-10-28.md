# Architecture review — 2026-10-28 (end of M1)

Survey: 2,284 lines of Swift, largest file `SelfTest.swift` (195 lines), no type over 200 lines, no duplicated private types, no fix log yet. Two targets: `ReachKit` (pure logic: matching, query kinds, ranking, web search URLs, hotkey model) and `Reach` (AppKit/SwiftUI). The signal for this review is the milestone end and the next ones: M2 and M3 add about ten new kinds of results.

## Result sources behind one seam  [Strong]

Files: Sources/Reach/Launcher/LauncherModel.swift (130 lines), AppIndex.swift, FileSearch.swift, Fallbacks.swift, Sources/ReachKit/QueryKind.swift
Signal: before a big feature (M2 folder browsing; M3 calculator, web search keywords, URLs, system commands, quit/hide, shell, dictionary, contacts); a dependency cannot be replaced in a test.
Problem: `LauncherModel.refresh()` is a `switch` over `QueryKind` that knows every source by name: how to call it, whether it is sync or async, when fallbacks apply, and how to rank. Adding the calculator (S-015) means editing `QueryKind`, the switch, the ranking call and the self-test. The self-test also depends on this Mac: it needs Safari, Visual Studio Code and a Spotlight-indexed `BRIEF.md`, because `AppIndex` and `FileSearch` cannot be swapped.
Proposal: one interface for every kind of result; the model asks all sources and merges.

```swift
/// Something that can answer a query: apps, files, the calculator, web searches.
protocol ResultSource {
    /// Results for `query`, each with a text score. May take time (Spotlight).
    func results(for query: Query) async -> [Scored]
    /// True when this source owns the query outright (a keyword like `open `)
    /// and the others must stay quiet.
    func claims(_ query: Query) -> Bool
}
struct Scored { var result: LaunchResult; var score: Int }

// LauncherModel(sources: [AppSource(), FileSource(), CalculatorSource()],
//               fallbacks: FallbackSource(), learning: learning)
```

Benefits: locality — a new result kind is one new file plus one line in the source list; `LauncherModel` stops growing per story. Leverage — Learning, the 9-result limit, fallbacks and stale-result handling apply to every source for free. A fake source makes the self-test independent of installed apps and Spotlight, so it runs the same on any Mac.
Proof of same behavior: the 34 self-test checks and 13 unit tests before and after; launcher snapshots (`APP_SNAPSHOT_PAGES=launcher`) compared side by side; per-keystroke time stays under 50 ms (already a check).
Plan:
1. Add `ResultSource`, `Scored`, and `AppSource`/`FileSource`/`FallbackSource` wrapping today's types (new files, compile, no callers yet).
2. Move `LauncherModel.refresh()` onto the source list; delete the switch.
3. Add a `FakeSource` for the self-test and replace the Safari / VS Code / BRIEF.md dependencies with it; keep one real-system check per source.

## App-wide singleton and test-run flag  [Speculative]

Files: Sources/Reach/Models.swift (`AppModel.shared`, `AppModel.isTestRun`), App.swift, Hotkey.swift
Signal: state reachable from everywhere.
Problem: `AppModel.shared` and `Store.isOverridden` are read from the delegate, the menu, the hotkey and the self-test. Fine at this size; it becomes a problem only if a second window or a CLI (`agent-cli`) needs its own model.
Proposal: none now. Revisit when the agent CLI or a second launcher arrives.

## File keywords hard-coded in QueryKind  [Speculative]

Files: Sources/ReachKit/QueryKind.swift
Signal: S-014 makes `open`, `find`, `in` and `tags` configurable.
Problem: the keyword list is a static array.
Proposal: do it inside S-014, where the settings exist; with the result-source seam each source reads its own keyword.

## Top recommendation

**Result sources behind one seam.** It is cheap now (three sources, ~150 lines to move) and every M2/M3 story gets easier after it. Doing it after M3 means moving ten sources instead of three.

## Considered, not recommended

- Splitting `SelfTest.swift` (195 lines): readable as one file per milestone section; split when it passes 400.
- A protocol around `HotkeyCenter`: one adapter (Carbon) and the self-test already drives it with test combinations; a seam would be hypothetical.
- Moving `Learning` into ReachKit: its logic (`Ranking`) is already there; what remains is SwiftData glue.

## Outcome

Done on 2026-10-28 in three commits (8c9673b, ee8e710, and the fake-source commit), plus ARCHITECTURE.md. Same behaviour: unit tests and self-test pass before and after, launcher snapshots within 0.11% of the baseline. The self-test went from 34 to 37 checks and no longer needs Visual Studio Code.
