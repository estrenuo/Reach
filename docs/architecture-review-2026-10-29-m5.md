# Architecture review — end of M5 (2026-10-29)

M5 (S-032 to S-040) added themes, Launcher Options, Search Settings, the
Settings rail, Advanced (Learning, query history, alternative actions),
sync through a folder and usage stats. Next is M6: workflows with script
filters.

Survey:

- Hot spots (30 days): `STORIES.md`, `ARCHITECTURE.md`, `Snapshot.swift`, `SelfTest.swift`, `LauncherModel.swift`.
- Largest files:
  - `LauncherModel.swift`, 611 lines. This is the only file over the 600 signal.
  - `ActionPanel.swift`, 362 lines.
  - `SelfTest+Launcher.swift`, 354 lines.
  - `Snapshot.swift`, 330 lines.
  - `LauncherPanel.swift`, 324 lines.
  - `AppearanceSettings.swift`, 323 lines.
- New logic went into ReachKit with unit tests (158 tests): `SettingsIndex`, `QueryHistory`, `SyncFolder`, `SnippetLibrary`, `UsageLog`. The app types only wire it to UserDefaults, SwiftData and views.
- No new `private struct` duplicates. `docs/FIXLOG.md` has no area with 3 entries.

## LauncherModel by feature  [Worth exploring]

Files: Sources/Reach/Launcher/LauncherModel.swift (611 lines)
Signal: a file over 600 lines; M6 adds workflow results and actions.
Problem: query and merge, history, selection and open, the action panel and the buffer share one file. The parts are already marked with MARK comments, but a change to the buffer means scrolling past the merge.
Proposal: move the action panel (`showActions`, `runAction`, `closeActions`, contacts fields) and the buffer into `LauncherModel+Actions.swift`, the way `LauncherModel+Clipboard.swift` already holds the viewer.
Cost: `actions`, `buffer` and `confirming` are `private(set)`, and `rewriteQuery` and `selectedFile` are `private`. An extension in another file cannot set them, so they would become internal and any caller could set them. That trades encapsulation for file size.
Benefits: about 200 lines out. No test gets simpler, because the self-test already drives the model through its public methods.
Proof of same behavior: `swift test` and `tools/selftest.sh`, before and after.
Plan: one commit. Do it when the file passes 800 lines or a workflow story needs to change the open path.

## Workflows as a ResultSource  [Worth exploring]

Files: Sources/Reach/Launcher/ResultSource.swift, the new Sources/Reach/Workflows/
Signal: before a big feature.
Problem: none today. The question is what change would make M6 easy.
Proposal: a script filter is one `WorkflowSource: ResultSource`. It runs the script off the main thread and answers through `later`, like Spotlight. The parsing of the Alfred JSON goes in ReachKit (`ScriptFilterOutput`), and so does reading `info.plist` (`Workflow`), with unit tests. The workflows folder is `SyncFolder.workflows` when a sync folder is set, else `~/Library/Application Support/Reach/Workflows`.
Benefits: no change to `LauncherModel` beyond one entry in `sources`, which also keeps the first card from growing.
Plan: S-041 builds it this way.

## Settings pages next to their feature  [Speculative]

Files: Sources/Reach/UI/*Settings*.swift (12 files)
Signal: a settings page far from its feature.
Problem: the pages sit in `UI/`, and their stores sit in `Launcher/` or `Clipboard/`. Finding a page is still easy: one file per tab, named after it.
Proposal: move each page to its feature folder.
Benefits: small. It moves files only.

## Top recommendation

None is `Strong`. The code is in good shape for M6, so I change nothing in this check-in. M6 builds workflows as a `ResultSource` with the logic in ReachKit (second card), so `LauncherModel` does not grow. Split `LauncherModel` (first card) when it passes 800 lines.

## Considered, not recommended

- Splitting `ActionPanel.swift` (362 lines). It is one list of actions and their filter, and it reads top to bottom.
- A protocol for `SyncService` and `UsageStore`. Each has one adapter, and the self-test reaches them through test stores in /tmp. A protocol would be a hypothetical seam.
- Moving `Snapshot.swift` captures into one file per page. It is a hot spot because every story adds a capture, not because a capture is hard to change.
